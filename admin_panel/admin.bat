@echo off
cd /d "%~dp0"
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)
call venv\Scripts\activate.bat
pip install -r requirements.txt

echo Pulling database from server...
python "C:\Users\milky\.gemini\antigravity-ide\brain\81272d13-7028-4d15-9a7a-0fdc1db387c0\scratch\sync_db.py"

python app.py

echo Pushing database to server...
python "C:\Users\milky\.gemini\antigravity-ide\brain\81272d13-7028-4d15-9a7a-0fdc1db387c0\scratch\push_db.py"

pause
