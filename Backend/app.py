import uvicorn
import time
from collections import defaultdict
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
import gradio as gr

# Import modules
from routes import router
from dashboard import create_dashboard
from config import ALLOWED_ORIGINS, DEBUG_MODE

# ============================================
# Rate Limiting Middleware
# ============================================
class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Simple in-memory rate limiter.
    Limits requests per IP address.
    """
    def __init__(self, app, requests_per_minute: int = 30):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.requests = defaultdict(list)
    
    async def dispatch(self, request: Request, call_next):
        # Get client IP
        client_ip = request.client.host if request.client else "unknown"
        
        # Only rate limit the upload endpoint
        if request.url.path == "/api/upload":
            now = time.time()
            minute_ago = now - 60
            
            # Clean old requests
            self.requests[client_ip] = [
                t for t in self.requests[client_ip] if t > minute_ago
            ]
            
            # Check rate limit
            if len(self.requests[client_ip]) >= self.requests_per_minute:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Please try again later."}
                )
            
            # Record this request
            self.requests[client_ip].append(now)
        
        return await call_next(request)


# ============================================
# Request Size Limit Middleware
# ============================================
class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    """
    Limits the maximum request body size.
    """
    def __init__(self, app, max_size_mb: int = 100):
        super().__init__(app)
        self.max_size = max_size_mb * 1024 * 1024
    
    async def dispatch(self, request: Request, call_next):
        content_length = request.headers.get("content-length")
        if content_length:
            if int(content_length) > self.max_size:
                raise HTTPException(
                    status_code=413,
                    detail=f"Request too large. Maximum size is {self.max_size // (1024*1024)}MB"
                )
        return await call_next(request)


# --- FastAPI Setup ---
app = FastAPI(
    title="PrintApp Backend",
    description="Print order management service",
    version="1.0.0",
    # Disable docs in production
    docs_url="/docs" if DEBUG_MODE else None,
    redoc_url="/redoc" if DEBUG_MODE else None,
    openapi_url="/openapi.json" if DEBUG_MODE else None,
)

# Add security middleware
app.add_middleware(RequestSizeLimitMiddleware, max_size_mb=100)  # 100MB total limit
app.add_middleware(RateLimitMiddleware, requests_per_minute=30)  # 30 uploads/min per IP

# Config CORS with environment-based origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Include API Routes
app.include_router(router)

# --- Gradio Setup (Keeps HF Space active) ---
demo = create_dashboard()

# Mount Gradio to FastAPI at root
app = gr.mount_gradio_app(app, demo, path="/")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
