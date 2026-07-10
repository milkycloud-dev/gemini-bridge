import typer
from sqlalchemy.orm import Session
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
import models
from models import SessionLocal, engine
import os

models.Base.metadata.create_all(bind=engine)

app = typer.Typer(help="Gemini Bridge Server CLI")
console = Console()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.command()
def dashboard():
    """Show server overview and stats."""
    db = next(get_db())
    total_clients = db.query(models.Client).count()
    active_clients = db.query(models.Client).filter(models.Client.is_active == True).count()
    total_reqs = db.query(models.RequestStat).count()
    
    text = Text()
    text.append(f"Total Registered Clients: {total_clients}\n", style="bold cyan")
    text.append(f"Active Clients: {active_clients}\n", style="bold green")
    text.append(f"Blocked Clients: {total_clients - active_clients}\n", style="bold red")
    text.append(f"Total Requests Processed: {total_reqs}\n", style="bold magenta")
    
    panel = Panel(text, title="Gemini Bridge Dashboard", border_style="blue")
    console.print(panel)

@app.command()
def clients():
    """List all registered clients with details."""
    db = next(get_db())
    clients = db.query(models.Client).all()
    
    table = Table(title="Registered Clients", border_style="cyan")
    table.add_column("ID", style="cyan", justify="right")
    table.add_column("Name", style="magenta")
    table.add_column("IP", style="green")
    table.add_column("HWID", style="yellow")
    table.add_column("Reqs", style="blue", justify="right")
    table.add_column("Active", style="bold")
    
    for c in clients:
        req_count = db.query(models.RequestStat).filter(models.RequestStat.client_id == c.id).count()
        active = "[green]Yes[/green]" if c.is_active else "[red]No[/red]"
        hwid_short = (c.hwid[:10] + "..") if c.hwid else "N/A"
        table.add_row(str(c.id), c.name, c.ip_address or "N/A", hwid_short, str(req_count), active)
        
    console.print(table)

@app.command()
def block(name: str):
    """Block a client by name."""
    db = next(get_db())
    client = db.query(models.Client).filter(models.Client.name == name).first()
    if not client:
        console.print(f"[red]Client '{name}' not found.[/red]")
        return
    client.is_active = False
    db.commit()
    console.print(f"[green]Client '{name}' blocked successfully.[/green]")

@app.command()
def unblock(name: str):
    """Unblock a client by name."""
    db = next(get_db())
    client = db.query(models.Client).filter(models.Client.name == name).first()
    if not client:
        console.print(f"[red]Client '{name}' not found.[/red]")
        return
    client.is_active = True
    db.commit()
    console.print(f"[green]Client '{name}' unblocked successfully.[/green]")

@app.command()
def history(name: str):
    """View chat history location or export for a client."""
    db = next(get_db())
    client = db.query(models.Client).filter(models.Client.name == name).first()
    if not client:
        console.print(f"[red]Client '{name}' not found.[/red]")
        return
        
    chats = db.query(models.Chat).filter(models.Chat.client_id == client.id).order_by(models.Chat.created_at.desc()).limit(5).all()
    if not chats:
        console.print(f"[yellow]No chat history found for '{name}'.[/yellow]")
        return
        
    console.print(f"[cyan]Recent Chats for {name}:[/cyan]")
    for chat in chats:
        console.print(f"\n[bold]Chat ID {chat.id}: {chat.title}[/bold] ({chat.created_at})")
        for m in chat.messages:
            role_color = "green" if m.role == "user" else "magenta"
            attachment = f" [blue](Attachment: {m.attachment_url})[/blue]" if m.attachment_url else ""
            console.print(f"[{role_color}]{m.role.upper()}[/{role_color}]: {m.content}{attachment}")

@app.command()
def clear_cache(name: str):
    """Clear the image/file cache for a specific client."""
    db = next(get_db())
    client = db.query(models.Client).filter(models.Client.name == name).first()
    if not client:
        console.print(f"[red]Client '{name}' not found.[/red]")
        return
        
    import shutil
    cache_dir = f"data/static/uploads/{client.id}"
    if os.path.exists(cache_dir):
        try:
            shutil.rmtree(cache_dir)
            console.print(f"[green]Successfully cleared cache for '{name}' at {cache_dir}.[/green]")
        except Exception as e:
            console.print(f"[red]Failed to clear cache: {e}[/red]")
    else:
        console.print(f"[yellow]No cache found for '{name}'.[/yellow]")

@app.command()
def set_token(name: str, token: str):
    """Set a custom Gemini token for a specific client."""
    db = next(get_db())
    client = db.query(models.Client).filter(models.Client.name == name).first()
    if not client:
        console.print(f"[red]Client '{name}' not found.[/red]")
        return
    client.gemini_token = token
    db.commit()
    console.print(f"[green]Custom Gemini token set for '{name}'.[/green]")

@app.command()
def set_default_token(token: str):
    """Set the default Gemini token for the server."""
    db = next(get_db())
    setting = db.query(models.Setting).filter(models.Setting.key == "default_gemini_token").first()
    if not setting:
        setting = models.Setting(key="default_gemini_token", value=token)
        db.add(setting)
    else:
        setting.value = token
    db.commit()
    console.print("[green]Default Gemini token updated.[/green]")

@app.command()
def toggle_registration(allow: bool):
    """Enable or disable new user registrations."""
    db = next(get_db())
    setting = db.query(models.Setting).filter(models.Setting.key == "allow_registration").first()
    allow_str = "true" if allow else "false"
    if not setting:
        setting = models.Setting(key="allow_registration", value=allow_str)
        db.add(setting)
    else:
        setting.value = allow_str
    db.commit()
    status = "enabled" if allow else "disabled"
    console.print(f"[green]Registration is now {status}.[/green]")

if __name__ == "__main__":
    app()
