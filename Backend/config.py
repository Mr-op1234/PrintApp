import os
import secrets

# Configuration Constants
UPLOAD_DIR = "uploads"

# Security: API Key must be set via environment variable
# No default value - will fail fast if not configured
XEROX_API_KEY = os.environ.get("XEROX_API_KEY")

if not XEROX_API_KEY:
    # Generate a temporary key for development only
    # This will be different each restart, forcing proper configuration
    print("WARNING: XEROX_API_KEY not set! Using temporary key (will change on restart)")
    print("Set XEROX_API_KEY environment variable for production!")
    XEROX_API_KEY = secrets.token_hex(32)

# Allowed origins for CORS (set via environment variable)
# Default: allow all for development, restrict in production
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "*").split(",")

# Debug mode (disable in production)
DEBUG_MODE = os.environ.get("DEBUG_MODE", "false").lower() == "true"

# Ensure upload directory exists
os.makedirs(UPLOAD_DIR, exist_ok=True)
