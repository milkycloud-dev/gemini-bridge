import os

def replace_in_file(filepath, replacements):
    if not os.path.exists(filepath):
        return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    for old, new in replacements.items():
        content = content.replace(old, new)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    print("Welcome to Gemini Bridge Setup!")
    print("Please enter your configuration details below.\n")

    telegram_bot_token = input("Enter your Telegram Bot Token: ").strip()
    telegram_chat_id = input("Enter your Telegram Chat ID: ").strip()
    app_secret = input("Enter a secure App Secret (used for client-server auth): ").strip()
    demo_api_key = input("Enter a Gemini API Key for demo mode (optional): ").strip()
    domain = input("Enter your domain name (e.g. gemini.yourdomain.com) or IP: ").strip()

    if not all([telegram_bot_token, telegram_chat_id, app_secret, domain]):
        print("Error: All fields are required except Demo API key!")
        return

    replacements = {
        "<YOUR_TELEGRAM_BOT_TOKEN>": telegram_bot_token,
        "<YOUR_TELEGRAM_CHAT_ID>": telegram_chat_id,
        "<YOUR_APP_SECRET>": app_secret,
        "<YOUR_DOMAIN>": domain,
        "<YOUR_DEMO_GEMINI_API_KEY>": demo_api_key
    }

    print("\nConfiguring files...")
    
    replace_in_file("docker-compose.yml", replacements)
    replace_in_file(os.path.join("server", "main.py"), replacements)
    replace_in_file(os.path.join("web-client", "lib", "api_service.dart"), replacements)
    
    admin_app = os.path.join("admin_panel", "app.py")
    admin_bat = os.path.join("admin_panel", "admin.bat")
    replace_in_file(admin_app, {"<YOUR_SERVER_IP>": domain})
    replace_in_file(admin_bat, {"<YOUR_SERVER_IP>": domain})
    
    print("Configuration complete! You can now run `docker-compose up -d --build` to start the server.")
    print("For the web client, run `flutter build web` inside the `web-client` directory.")

if __name__ == "__main__":
    main()
