from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File, Form, Request, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
import models
import schemas
from models import SessionLocal, engine
import bcrypt
import logging
import time
import os
import uuid
import mimetypes
import json
import re
import requests
import html
import asyncio
from pydantic import BaseModel
import os

DATA_DIR = os.environ.get("DATA_DIR", "data")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler("app.log"), logging.StreamHandler()]
)
logger = logging.getLogger("gemini-bridge")

# Create DB tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Gemini Bridge")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://gemini.milkycloud.online"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs(f"{DATA_DIR}/static/updates", exist_ok=True)
os.makedirs(f"{DATA_DIR}/history", exist_ok=True)
app.mount("/static", StaticFiles(directory=f"{DATA_DIR}/static"), name="static")

@app.middleware("http")
async def check_banned_ip_middleware(request: Request, call_next):
    ip_addr = request.client.host if request.client else None
    if ip_addr:
        db = SessionLocal()
        try:
            is_banned = db.query(models.BannedIP).filter(models.BannedIP.ip_address == ip_addr).first()
            if is_banned:
                return StreamingResponse(
                    iter([b'{"detail": "Your IP address has been banned."}']), 
                    status_code=403, 
                    media_type="application/json"
                )
        finally:
            db.close()
            
    response = await call_next(request)
    return response

async def telegram_poller():
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    if not bot_token: return
    offset = 0
    url = f"https://api.telegram.org/bot{bot_token.strip()}/getUpdates"
    while True:
        try:
            # Use asyncio.to_thread to prevent blocking the main FastAPI event loop
            res = await asyncio.to_thread(requests.get, f"{url}?offset={offset}&timeout=30", timeout=35)
            if res.status_code == 200:
                data = res.json()
                for update in data.get("result", []):
                    offset = update["update_id"] + 1
                    msg = update.get("message")
                    if not msg: continue
                    
                    text = msg.get("text", "")
                    reply_to = msg.get("reply_to_message")
                    
                    if reply_to and "New Registration!" in reply_to.get("text", ""):
                        orig_text = reply_to["text"]
                        match = re.search(r'Name:\s*([^\n]+)', orig_text)
                        if match and text.strip():
                            user_name = match.group(1).strip()
                            token_to_assign = text.strip()
                            
                            db = SessionLocal()
                            try:
                                client = db.query(models.Client).filter(models.Client.name == user_name).first()
                                if client:
                                    client.gemini_token = token_to_assign
                                    db.commit()
                                    chat_id = msg["chat"]["id"]
                                    send_url = f"https://api.telegram.org/bot{bot_token.strip()}/sendMessage"
                                    await asyncio.to_thread(requests.post, send_url, json={
                                        "chat_id": chat_id,
                                        "text": f"✅ Token assigned to {user_name}!",
                                        "reply_to_message_id": msg["message_id"]
                                    })
                            finally:
                                db.close()
        except Exception as e:
            await asyncio.sleep(5)
            continue
        await asyncio.sleep(1)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(telegram_poller())

# Smart memory rate limiter
from collections import defaultdict
client_requests = defaultdict(list)

def check_rate_limit(client_id: int):
    now = time.time()
    # Retain only last 60s
    client_requests[client_id] = [t for t in client_requests[client_id] if now - t < 60]
    reqs = client_requests[client_id]
    
    if len(reqs) >= 1:
        logger.warning(f"Rate limit exceeded for client {client_id}")
        raise HTTPException(status_code=429, detail="Слишком частые запросы. Разрешено 1 сообщение в 60 секунд.")
    
    client_requests[client_id].append(now)

# IP Rate limiter for auth
auth_requests = defaultdict(list)

def check_auth_rate_limit(ip: str):
    if not ip: return
    now = time.time()
    # Retain only last 60s
    auth_requests[ip] = [t for t in auth_requests[ip] if now - t < 60]
    reqs = auth_requests[ip]
    
    if len(reqs) >= 10:
        logger.warning(f"Auth rate limit exceeded for IP {ip}")
        raise HTTPException(status_code=429, detail="Слишком много попыток входа/регистрации. Попробуйте через минуту.")
    
    auth_requests[ip].append(now)

def notify_telegram(name: str, hwid: str, ip: str):
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    
    logger.info(f"Starting telegram notification for {name}, bot_token_length={len(bot_token) if bot_token else 0}, chat_id={chat_id}")
    
    if not bot_token or not chat_id:
        logger.error("Telegram credentials not configured in environment variables.")
        return
        
    name_safe = html.escape(str(name) if name else "Unknown")
    hwid_safe = html.escape(str(hwid) if hwid else "Unknown")
    ip_safe = html.escape(str(ip) if ip else "Unknown")
    text = f"🆕 <b>New Registration!</b>\n\n👤 Name: {name_safe}\n🖥 HWID: {hwid_safe}\n🌐 IP: {ip_safe}\n\nPlease assign a Gemini API key."
    url = f"https://api.telegram.org/bot{bot_token.strip()}/sendMessage"
    try:
        res = requests.post(url, json={"chat_id": chat_id.strip(), "text": text, "parse_mode": "HTML"}, timeout=5)
        if res.status_code != 200:
            logger.error(f"Telegram API error: {res.text}")
        else:
            logger.info(f"Telegram notification sent successfully! Response: {res.text}")
    except Exception as e:
        logger.error(f"Failed to send telegram notification: {e}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_client(
    server_token: str = Header(...), 
    x_app_secret: str = Header(..., alias="X-App-Secret"),
    db: Session = Depends(get_db)
):
    if x_app_secret != "GeminiBridge-SecureClient-2026!":
        raise HTTPException(status_code=403, detail="Unauthorized client")
        
    client = db.query(models.Client).filter(models.Client.server_token == server_token).first()
    if not client:
        raise HTTPException(status_code=401, detail="Invalid server token")
    if not client.is_active:
        raise HTTPException(status_code=403, detail="Client is blocked")
    return client

def get_setting(db: Session, key: str, default: str = None):
    setting = db.query(models.Setting).filter(models.Setting.key == key).first()
    return setting.value if setting else default

@app.get("/api/version")
def get_version(request: Request, db: Session = Depends(get_db)):
    version = get_setting(db, "client_version") or "1.0"
    base_url = str(request.base_url).rstrip("/")
    return {
        "version": version,
        "update_url": f"{base_url}/static/updates/gemini_bridge_client_{version}.exe"
    }

@app.post("/register", response_model=schemas.RegisterResponse)
def register(
    req: schemas.RegisterRequest, 
    request: Request,
    background_tasks: BackgroundTasks,
    x_app_secret: str = Header(..., alias="X-App-Secret"),
    db: Session = Depends(get_db)
):
    if x_app_secret != "GeminiBridge-SecureClient-2026!":
        raise HTTPException(status_code=403, detail="Unauthorized client")
        
    # Check if auto-assign is enabled
    auto_assign = get_setting(db, "allow_registration", "true")
    if auto_assign.lower() != "true":
        raise HTTPException(status_code=403, detail="Регистрация новых аккаунтов в данный момент закрыта.")
    
    # Check if user already exists
    existing = db.query(models.Client).filter(models.Client.name == req.name).first()
    if existing:
        if not existing.gemini_token and existing.password_hash:
            try:
                if bcrypt.checkpw(req.password.encode('utf-8'), existing.password_hash.encode('utf-8')):
                    logger.info(f"Idempotent registration return for {existing.name}")
                    return {"server_token": existing.server_token, "message": "Registration successful"}
            except Exception:
                pass
        raise HTTPException(status_code=403, detail="Пользователь с таким именем уже существует.")
        
    ip_addr = request.client.host if request.client else None
    check_auth_rate_limit(ip_addr)
    
    # Generate bcrypt hash
    salt = bcrypt.gensalt(rounds=4)
    hashed_pwd = bcrypt.hashpw(req.password.encode('utf-8'), salt).decode('utf-8')
    
    client = models.Client(name=req.name, password_hash=hashed_pwd, ip_address=ip_addr, hwid=req.hwid, device_info=req.device_info)
    db.add(client)
    db.commit()
    db.refresh(client)
    logger.info(f"New client registered: {client.name} (IP: {ip_addr})")
    
    background_tasks.add_task(notify_telegram, req.name, req.hwid, ip_addr)
    
    return {"server_token": client.server_token, "message": "Registration successful"}

@app.post("/login", response_model=schemas.RegisterResponse)
def login(
    req: schemas.LoginRequest, 
    request: Request,
    x_app_secret: str = Header(..., alias="X-App-Secret"),
    db: Session = Depends(get_db)
):
    if x_app_secret != "GeminiBridge-SecureClient-2026!":
        raise HTTPException(status_code=403, detail="Unauthorized client")
        
    client = db.query(models.Client).filter(models.Client.name == req.name).first()
    if not client:
        raise HTTPException(status_code=403, detail="Неверное имя пользователя или пароль.")
        
    if not client.password_hash:
        raise HTTPException(status_code=403, detail="Неверное имя пользователя или пароль.")
    
    try:
        is_valid = bcrypt.checkpw(req.password.encode('utf-8'), client.password_hash.encode('utf-8'))
        if not is_valid:
            raise HTTPException(status_code=403, detail="Неверное имя пользователя или пароль.")
            
        # Upgrade hash if it uses older/higher rounds
        if not client.password_hash.startswith("$2b$04$"):
            salt = bcrypt.gensalt(rounds=4)
            client.password_hash = bcrypt.hashpw(req.password.encode('utf-8'), salt).decode('utf-8')
            
    except Exception:
        raise HTTPException(status_code=403, detail="Неверное имя пользователя или пароль.")
        
    ip_addr = request.client.host if request.client else None
    check_auth_rate_limit(ip_addr)
    client.ip_address = ip_addr
    if req.hwid:
        client.hwid = req.hwid
    db.commit()
    
    logger.info(f"Client logged in: {client.name} (IP: {ip_addr})")
    return {"server_token": client.server_token, "message": "Login successful"}

@app.get("/api/status")
def get_status(client: models.Client = Depends(get_current_client)):
    return {"has_token": bool(client.gemini_token)}

class CustomTokenRequest(BaseModel):
    gemini_token: str

@app.post("/api/set_custom_token")
def set_custom_token(req: CustomTokenRequest, client: models.Client = Depends(get_current_client), db: Session = Depends(get_db)):
    client.gemini_token = req.gemini_token
    db.commit()
    return {"status": "ok"}

class HwidRequest(BaseModel):
    hwid: str

@app.post("/api/update_hwid")
def update_hwid(req: HwidRequest, client: models.Client = Depends(get_current_client), db: Session = Depends(get_db)):
    client.hwid = req.hwid
    db.commit()
    return {"status": "ok"}

@app.post("/api/cheat_demo")
def activate_demo(client: models.Client = Depends(get_current_client), db: Session = Depends(get_db)):
    client.gemini_token = "DEMO_TOKEN_NOT_REAL"
    db.commit()
    
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    if bot_token and chat_id:
        url = f"https://api.telegram.org/bot{bot_token.strip()}/sendMessage"
        text = f"🔴 <b>DEMO MODE ACTIVATED</b> 🔴\n\nUser {html.escape(client.name)} activated the demo cheat code!"
        try:
            requests.post(url, json={"chat_id": chat_id.strip(), "text": text, "parse_mode": "HTML"})
        except: pass
    
    return {"status": "ok"}

@app.get("/chats", response_model=List[schemas.ChatListResponse])
def get_chats(client: models.Client = Depends(get_current_client), db: Session = Depends(get_db)):
    chats = db.query(models.Chat).filter(models.Chat.client_id == client.id).order_by(models.Chat.created_at.desc()).all()
    return chats

@app.get("/chats/{chat_id}/history", response_model=schemas.ChatHistoryResponse)
def get_chat_history(chat_id: int, client: models.Client = Depends(get_current_client), db: Session = Depends(get_db)):
    chat = db.query(models.Chat).filter(models.Chat.id == chat_id, models.Chat.client_id == client.id).first()
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    return {"id": chat.id, "title": chat.title, "messages": chat.messages}

@app.post("/chat")
async def chat(
    request: Request,
    client: models.Client = Depends(get_current_client),
    prompt: str = Form(...),
    model: str = Form("Gemini 2.5 Pro"),
    chat_id: Optional[int] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    check_rate_limit(client.id)
    
    # Load history
    history_path = f"{DATA_DIR}/history/{client.id}.json"
    
    # Log telemetry
    ip_addr = request.client.host if request.client else None
    stat = models.RequestStat(client_id=client.id, endpoint="/chat", ip_address=ip_addr)
    db.add(stat)
    db.commit()
    
    logger.info(f"Client {client.name} initiated chat request. Model: {model}")
    
    # Get Gemini Token
    gemini_token = client.gemini_token
    if not gemini_token:
        logger.error(f"Gemini token not configured for client {client.name}")
        raise HTTPException(status_code=403, detail="Gemini key not assigned yet.")
        
    genai.configure(api_key=gemini_token)
    
    # Map model name
    # The client might send "Gemini 2.5 Flash", "Gemini 2.5 Flash-Lite", "Gemini 2.5 Pro"
    # We map it to actual Gemini API model names. Assuming they are gemini-2.5-pro etc.
    # We will use what is requested or fallback
    api_model = "gemini-2.5-pro"
    if "Flash-Lite" in model:
        api_model = "gemini-2.5-flash-lite"
    elif "Flash" in model:
        api_model = "gemini-2.5-flash"
    elif "Pro" in model:
        api_model = "gemini-2.5-pro"
        
    system_instruction = "Ты — ИИ-ассистент MilkyCloud Gemini. Если пользователь просит тебя сгенерировать, нарисовать или создать картинку/изображение, выведи специальный тег: [GENERATE_IMAGE: <подробное описание картинки на английском языке>] и больше ничего. В остальных случаях отвечай как обычно."
    gen_model = genai.GenerativeModel(api_model, system_instruction=system_instruction)
    
    # Retrieve or create chat
    if chat_id:
        chat_obj = db.query(models.Chat).filter(models.Chat.id == chat_id, models.Chat.client_id == client.id).first()
        if not chat_obj:
            raise HTTPException(status_code=404, detail="Chat not found")
    else:
        title = prompt[:30] + "..." if len(prompt) > 30 else prompt
        if not title.strip() and file:
            title = "[Изображение]"
        chat_obj = models.Chat(client_id=client.id, title=title)
        db.add(chat_obj)
        db.commit()
        db.refresh(chat_obj)
        chat_id = chat_obj.id
        
    # We will create the user_msg object later after saving the attachment
    user_msg_id = None
    
    # Prepare history for Gemini
    history = []
    messages = db.query(models.Message).filter(models.Message.chat_id == chat_id).order_by(models.Message.created_at.asc()).all()
    
    # Filter empty messages or repeating roles
    filtered_messages = []
    last_role = None
    for m in messages:
        # Ignore empty messages
        if not m.content.strip() and not m.attachment_url:
            continue
            
        role = "user" if m.role == "user" else "model"
        content = m.content.strip()
        if not content:
            content = "[Пользователь прикрепил файл]"
        
        # Ensure alternating roles
        if role == last_role:
            filtered_messages[-1]["parts"][0] += f"\n\n{content}"
        else:
            filtered_messages.append({"role": role, "parts": [content]})
        last_role = role
            
    # Ensure history ends with 'model' or is empty, because the next message we send is from 'user'
    if filtered_messages and filtered_messages[-1]["role"] == "user":
        # If the last message was user (e.g. error happened), we just pop it or convert to model
        filtered_messages.pop()
            
    history = filtered_messages
    chat_session = gen_model.start_chat(history=history)
    
    content_parts = []
    if prompt.strip():
        content_parts.append(f"[{client.name}]: {prompt}")
    elif file:
        content_parts.append(f"[{client.name}]: Опиши это изображение или ответь на то, что на нем.")

    attachment_url = None
    if file:
        try:
            
            # Save file to disk in user-specific folder
            file_bytes = await file.read()
            safe_filename = os.path.basename(file.filename)
            filename = f"{uuid.uuid4().hex}_{safe_filename}"
            user_dir = f"data/static/uploads/{client.id}"
            os.makedirs(user_dir, exist_ok=True)
            file_path = f"{user_dir}/{filename}"
            with open(file_path, "wb") as f:
                f.write(file_bytes)
                
            attachment_url = f"/static/uploads/{client.id}/{filename}"
            
            # Use mimetypes to correctly guess type, fallback to client content_type
            guessed_mime, _ = mimetypes.guess_type(file.filename)
            mime_type = guessed_mime or file.content_type or "application/octet-stream"
            
            # Upload to Gemini File API
            uploaded_file = genai.upload_file(path=file_path, mime_type=mime_type)
            content_parts.append(uploaded_file)
            
        except Exception as e:
            logger.error(f"Error processing inline file: {e}")

    # Save user message now that we have the attachment_url
    user_msg = models.Message(chat_id=chat_id, role="user", content=prompt, attachment_url=attachment_url)
    db.add(user_msg)
    db.commit()
            
    try:
        response = chat_session.send_message(content_parts)
        response_text = response.text
        
        # Intercept Imagen generation
        if "[GENERATE_IMAGE:" in response_text:

            match = re.search(r'\[GENERATE_IMAGE:(.*?)\]', response_text)
            if match:
                image_prompt = match.group(1).strip()
                # Генерация изображений отключена по просьбе пользователя
                warning_msg = "\n\n⚠️ Генерация изображений отключена.\n\n"
                response_text = response_text.replace(match.group(0), warning_msg)

    except Exception as e:
        response_text = f"Error communicating with Gemini: {str(e)}"
        
    # Save bot message
    bot_msg = models.Message(chat_id=chat_id, role="model", content=response_text)
    db.add(bot_msg)
    db.commit()
    db.refresh(bot_msg)
    
    # Save to file system history.md
    hwid_str = client.hwid if client.hwid else "unknown_hwid"
    user_dir = os.path.join("data", "users", f"{client.name}_{hwid_str}")
    os.makedirs(user_dir, exist_ok=True)
    history_file = os.path.join(user_dir, "history.md")
    with open(history_file, "a", encoding="utf-8") as f:
        import datetime
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"## {now_str} - Chat: {chat_obj.title} (ID: {chat_id})\n")
        f.write(f"**User**: {prompt}\n\n**Gemini**: {response_text}\n\n---\n")
    
    # Token tracking
    project_limit = 1000000
    try:
        # Approximate tokens based on characters (4 chars = 1 token roughly, for prompt + response)
        # Gemini API doesn't always return exact usage in simple text response, so we estimate
        tokens_used = (len(prompt) + len(response_text)) // 4
        
        # Read project total tokens
        project_tokens_file = "data/project_tokens.txt"
        total_project_used = 0
        if os.path.exists(project_tokens_file):
            with open(project_tokens_file, "r") as f:
                total_project_used = int(f.read().strip() or "0")
                
        total_project_used += tokens_used
        with open(project_tokens_file, "w") as f:
            f.write(str(total_project_used))
            
        project_remaining = max(0, project_limit - total_project_used)
        
        # Track per-user detailed tokens
        tokens_file = os.path.join(user_dir, "tokens.md")
        with open(tokens_file, "a", encoding="utf-8") as f:
            now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"- {now_str} | Chat: {chat_id} | Used: {tokens_used}\n")
            
    except Exception as e:
        logger.error(f"Error tracking tokens: {e}")
        project_remaining = 0
        tokens_used = 0
    
    return {
        "chat_id": chat_id,
        "response": response_text,
        "tokens_used": tokens_used,
        "tokens_remaining": project_remaining,
        "attachment_url": attachment_url
    }

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting Gemini Bridge Server...")
    logger.info("Initializing database and directories...")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
