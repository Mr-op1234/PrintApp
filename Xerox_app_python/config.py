"""Configuration management for Xerox Manager"""
import os
import json
import hashlib

CONFIG_FILE = os.path.join(os.path.expanduser("~"), ".xerox_manager", "config.json")
PDF_DIR = os.path.join(os.path.expanduser("~"), ".xerox_manager", "pdfs")
SCREENSHOT_DIR = os.path.join(os.path.expanduser("~"), ".xerox_manager", "screenshots")
DB_FILE = os.path.join(os.path.expanduser("~"), ".xerox_manager", "orders.db")

# ============================================
# HARDCODED CONFIGURATION - EDIT THESE VALUES
# ============================================
HARDCODED_WS_URL = "wss://itsmrop-iem-print-gurukul.hf.space/ws/xerox"
HARDCODED_API_TOKEN = "7ce91e6fc0a8eb38b883a7d0b115fb6c3102aea47041e4ff28f178ad401cfbcf"

# Application lock password (change this to your desired password)
APP_PASSWORD = "xerox123"

# ============================================

DEFAULT_CONFIG = {
    "ws_url": HARDCODED_WS_URL,
    "api_token": HARDCODED_API_TOKEN,
    "password_hash": hashlib.sha256(APP_PASSWORD.encode()).hexdigest(),
}

def ensure_dirs():
    """Create necessary directories"""
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    os.makedirs(PDF_DIR, exist_ok=True)
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)

def load_config():
    """Load configuration - uses hardcoded values"""
    ensure_dirs()
    # Always use hardcoded values for ws_url and api_token
    config = {
        "ws_url": HARDCODED_WS_URL,
        "api_token": HARDCODED_API_TOKEN,
    }
    return config

def save_config(config):
    """Save configuration to file"""
    ensure_dirs()
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)

def verify_password(password: str) -> bool:
    """Verify the application password"""
    return hashlib.sha256(password.encode()).hexdigest() == hashlib.sha256(APP_PASSWORD.encode()).hexdigest()

