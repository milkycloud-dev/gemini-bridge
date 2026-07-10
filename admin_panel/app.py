import customtkinter as ctk
import tkinter.messagebox as messagebox
import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add server to path to import models
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'server')))
import models
import bcrypt

# Connect to database
DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data', 'gemini_bridge.db'))
engine = create_engine(f"sqlite:///{DB_PATH}")
Session = sessionmaker(bind=engine)

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class AdminPanel(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Gemini Bridge - Admin Panel")
        self.geometry("800x600")
        
        # UI Elements
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        self.header = ctk.CTkLabel(self, text="Account Management", font=("Roboto", 24, "bold"))
        self.header.grid(row=0, column=0, pady=10)
        
        self.scroll_frame = ctk.CTkScrollableFrame(self)
        self.scroll_frame.grid(row=1, column=0, sticky="nsew", padx=20, pady=10)
        
        self.btn_frame = ctk.CTkFrame(self)
        self.btn_frame.grid(row=2, column=0, pady=10, sticky="ew", padx=20)
        
        self.refresh_btn = ctk.CTkButton(self.btn_frame, text="Refresh", command=self.load_users)
        self.refresh_btn.pack(side="left", padx=10)
        
        self.add_btn = ctk.CTkButton(self.btn_frame, text="Add User", command=self.add_user_dialog)
        self.add_btn.pack(side="left", padx=10)
        
        self.clear_btn = ctk.CTkButton(self.btn_frame, text="Clear All Accounts", fg_color="red", hover_color="darkred", command=self.clear_all)
        self.clear_btn.pack(side="right", padx=10)
        
        self.load_users()

    def load_users(self):
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()
            
        session = Session()
        clients = session.query(models.Client).all()
        
        for idx, client in enumerate(clients):
            frame = ctk.CTkFrame(self.scroll_frame)
            frame.pack(fill="x", pady=5, padx=5)
            
            status_text = "Active" if client.is_active else "BANNED"
            info = f"ID: {client.id} | Name: {client.name} | Status: {status_text} | IP: {client.ip_address} | Token: {'✅ Yes' if client.gemini_token else '❌ No'}"
            lbl = ctk.CTkLabel(frame, text=info)
            lbl.pack(side="left", padx=10, pady=10)
            
            btn_edit = ctk.CTkButton(frame, text="Set Token", width=80, command=lambda c=client: self.set_token(c.id))
            btn_edit.pack(side="right", padx=5, pady=10)
            
            btn_history = ctk.CTkButton(frame, text="History", width=80, command=lambda c=client: self.view_history(c))
            btn_history.pack(side="right", padx=5, pady=10)

            is_ip_banned = session.query(models.BannedIP).filter_by(ip_address=client.ip_address).first() is not None
            if is_ip_banned:
                btn_ip_ban = ctk.CTkButton(frame, text="Unban IP", fg_color="green", hover_color="darkgreen", width=80, command=lambda c=client: self.unban_ip(c.ip_address))
            else:
                btn_ip_ban = ctk.CTkButton(frame, text="Ban IP", fg_color="orange", hover_color="darkorange", width=80, command=lambda c=client: self.ban_ip(c.ip_address))
            btn_ip_ban.pack(side="right", padx=5, pady=10)
            
            if client.is_active:
                btn_acc_ban = ctk.CTkButton(frame, text="Ban Acc", fg_color="orange", hover_color="darkorange", width=80, command=lambda c=client: self.ban_account(c.id))
            else:
                btn_acc_ban = ctk.CTkButton(frame, text="Unban Acc", fg_color="green", hover_color="darkgreen", width=80, command=lambda c=client: self.unban_account(c.id))
            btn_acc_ban.pack(side="right", padx=5, pady=10)
            
            btn_del = ctk.CTkButton(frame, text="Delete", fg_color="red", hover_color="darkred", width=80, command=lambda c=client: self.delete_user(c.id))
            btn_del.pack(side="right", padx=5, pady=10)
            
        session.close()

    def add_user_dialog(self):
        dialog = ctk.CTkToplevel(self)
        dialog.title("Add New User")
        dialog.geometry("300x200")
        dialog.grab_set()
        
        ctk.CTkLabel(dialog, text="Name:").pack(pady=5)
        name_entry = ctk.CTkEntry(dialog)
        name_entry.pack(pady=5)
        
        ctk.CTkLabel(dialog, text="Password:").pack(pady=5)
        pwd_entry = ctk.CTkEntry(dialog, show="*")
        pwd_entry.pack(pady=5)
        
        def save():
            name = name_entry.get().strip()
            pwd = pwd_entry.get()
            if name and pwd:
                session = Session()
                if session.query(models.Client).filter_by(name=name).first():
                    messagebox.showerror("Error", "User already exists!")
                    session.close()
                    return
                salt = bcrypt.gensalt()
                hashed_pwd = bcrypt.hashpw(pwd.encode('utf-8'), salt).decode('utf-8')
                new_client = models.Client(name=name, password_hash=hashed_pwd, ip_address="AdminPanel", hwid="Admin-Created")
                session.add(new_client)
                session.commit()
                session.close()
                dialog.destroy()
                self.load_users()
            else:
                messagebox.showerror("Error", "Name and Password required")
                
        ctk.CTkButton(dialog, text="Create", command=save).pack(pady=15)

    def set_token(self, client_id):
        dialog = ctk.CTkToplevel(self)
        dialog.title("Set Token")
        dialog.geometry("400x180")
        dialog.grab_set()
        
        ctk.CTkLabel(dialog, text="Enter new Gemini API Token:").pack(pady=5)
        
        token_entry = ctk.CTkEntry(dialog, width=350)
        token_entry.pack(pady=5)
        
        # Load existing token if any
        session = Session()
        client = session.query(models.Client).filter_by(id=client_id).first()
        if client and client.gemini_token:
            token_entry.insert(0, client.gemini_token)
        session.close()
        
        def paste():
            try:
                text = dialog.clipboard_get()
                token_entry.delete(0, 'end')
                token_entry.insert(0, text)
            except:
                pass
                
        def save():
            token = token_entry.get().strip()
            session = Session()
            client = session.query(models.Client).filter_by(id=client_id).first()
            if client:
                client.gemini_token = token if token else None
                session.commit()
            session.close()
            dialog.destroy()
            self.load_users()

        btn_frame = ctk.CTkFrame(dialog, fg_color="transparent")
        btn_frame.pack(pady=15)
        
        ctk.CTkButton(btn_frame, text="Paste from Clipboard", width=120, command=paste).pack(side="left", padx=10)
        ctk.CTkButton(btn_frame, text="Save", width=80, command=save).pack(side="left", padx=10)

    def delete_user(self, client_id):
        if messagebox.askyesno("Confirm", "Are you sure you want to delete this user?"):
            session = Session()
            client = session.query(models.Client).filter_by(id=client_id).first()
            if client:
                session.delete(client)
                session.commit()
            session.close()
            self.load_users()

    def view_history(self, client):
        hwid_str = client.hwid if client.hwid else "unknown_hwid"
        history_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data', 'users', f"{client.name}_{hwid_str}", 'history.md'))
        if os.path.exists(history_path):
            os.startfile(history_path)
        else:
            messagebox.showinfo("History", "No history found for this user. Maybe they haven't sent any messages yet, or you haven't synced.")

    def ban_ip(self, ip_address):
        if not ip_address or ip_address == "AdminPanel":
            messagebox.showerror("Error", "Invalid IP address.")
            return
            
        if messagebox.askyesno("Confirm Ban", f"Are you sure you want to ban IP: {ip_address}?"):
            session = Session()
            if not session.query(models.BannedIP).filter_by(ip_address=ip_address).first():
                banned = models.BannedIP(ip_address=ip_address, reason="Banned from Admin Panel")
                session.add(banned)
                session.commit()
                messagebox.showinfo("Success", f"IP {ip_address} has been banned.")
            else:
                messagebox.showinfo("Info", "IP is already banned.")
            session.close()
            self.load_users()

    def unban_ip(self, ip_address):
        if messagebox.askyesno("Confirm Unban", f"Unban IP: {ip_address}?"):
            session = Session()
            banned = session.query(models.BannedIP).filter_by(ip_address=ip_address).first()
            if banned:
                session.delete(banned)
                session.commit()
            session.close()
            self.load_users()

    def ban_account(self, client_id):
        if messagebox.askyesno("Confirm Ban", "Ban this account?"):
            session = Session()
            client = session.query(models.Client).filter_by(id=client_id).first()
            if client:
                client.is_active = False
                session.commit()
            session.close()
            self.load_users()

    def unban_account(self, client_id):
        if messagebox.askyesno("Confirm Unban", "Unban this account?"):
            session = Session()
            client = session.query(models.Client).filter_by(id=client_id).first()
            if client:
                client.is_active = True
                session.commit()
            session.close()
            self.load_users()

    def clear_all(self):
        if messagebox.askyesno("DANGER", "Are you absolutely sure you want to DELETE ALL accounts and chat history?"):
            session = Session()
            session.query(models.Message).delete()
            session.query(models.Chat).delete()
            session.query(models.RequestStat).delete()
            session.query(models.Client).delete()
            session.commit()
            session.close()
            self.load_users()
            messagebox.showinfo("Success", "All accounts and history deleted.")

if __name__ == "__main__":
    app = AdminPanel()
    app.mainloop()
