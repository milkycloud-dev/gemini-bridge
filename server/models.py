from sqlalchemy import create_engine, Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
import datetime
import uuid

Base = declarative_base()

class Client(Base):
    __tablename__ = 'clients'
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    ip_address = Column(String, nullable=True)
    hwid = Column(String, nullable=True)
    device_info = Column(String, nullable=True)
    password_hash = Column(String, nullable=True)
    server_token = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    gemini_token = Column(String, nullable=True) # If null, use default
    is_active = Column(Boolean, default=True)
    chats = relationship("Chat", back_populates="client")
    stats = relationship("RequestStat", back_populates="client", cascade="all, delete-orphan")

class Setting(Base):
    __tablename__ = 'settings'
    key = Column(String, primary_key=True, index=True)
    value = Column(String)

class Chat(Base):
    __tablename__ = 'chats'
    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(Integer, ForeignKey('clients.id'))
    title = Column(String, default="New Chat")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    client = relationship("Client", back_populates="chats")
    messages = relationship("Message", back_populates="chat", cascade="all, delete-orphan")

class BannedIP(Base):
    __tablename__ = "banned_ips"
    
    id = Column(Integer, primary_key=True, index=True)
    ip_address = Column(String, unique=True, index=True)
    reason = Column(String, nullable=True)

class Message(Base):
    __tablename__ = 'messages'
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey('chats.id'))
    role = Column(String) # 'user' or 'model'
    content = Column(String)
    attachment_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    chat = relationship("Chat", back_populates="messages")

class RequestStat(Base):
    __tablename__ = 'request_stats'
    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(Integer, ForeignKey('clients.id'))
    endpoint = Column(String)
    ip_address = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    client = relationship("Client", back_populates="stats")

import os
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./gemini_bridge.db")
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
