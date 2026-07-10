from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class RegisterRequest(BaseModel):
    name: str
    password: str
    hwid: Optional[str] = None
    device_info: Optional[str] = None

class LoginRequest(BaseModel):
    name: str
    password: str
    hwid: Optional[str] = None

class RegisterResponse(BaseModel):
    server_token: str
    message: str

class ChatMessageBase(BaseModel):
    role: str
    content: str

class ChatMessageResponse(ChatMessageBase):
    id: int
    created_at: datetime
    attachment_url: Optional[str] = None
    
    class Config:
        from_attributes = True

class ChatListResponse(BaseModel):
    id: int
    title: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class ChatHistoryResponse(BaseModel):
    id: int
    title: str
    messages: List[ChatMessageResponse]

class ChatRequest(BaseModel):
    chat_id: Optional[int] = None
    prompt: str
    model: str = "gemini-2.5-pro" # flash, flash-lite, pro
