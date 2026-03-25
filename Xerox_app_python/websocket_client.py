"""WebSocket client for receiving orders"""
import asyncio
import websockets
import json
import base64
import os
import threading
import logging
from typing import Callable, Optional
from config import PDF_DIR, SCREENSHOT_DIR, ensure_dirs
from models import PrintOrder

# Setup file logging for debugging
LOG_DIR = os.path.join(os.path.expanduser("~"), ".xerox_manager")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "websocket_debug.log")

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, mode='w'),
    ]
)
logger = logging.getLogger(__name__)
logger.info(f"WebSocket client logging to: {LOG_FILE}")

class WebSocketClient:
    def __init__(self, on_order: Callable, on_status: Callable, on_error: Callable, on_screenshot: Callable = None):
        self.on_order = on_order
        self.on_status = on_status
        self.on_error = on_error
        self.on_screenshot = on_screenshot  # Callback for screenshot received
        self.ws: Optional[websockets.WebSocketClientProtocol] = None
        self.running = False
        self.thread: Optional[threading.Thread] = None
        self.loop: Optional[asyncio.AbstractEventLoop] = None
        self._current_file_data = b""
        self._current_metadata = None
        self._pending_screenshots = {}  # order_id -> screenshot_path
        
    def connect(self, ws_url: str, api_token: str):
        """Start WebSocket connection in background thread"""
        self.running = True
        self.thread = threading.Thread(target=self._run_async, args=(ws_url, api_token), daemon=True)
        self.thread.start()
    
    def disconnect(self):
        """Disconnect WebSocket"""
        self.running = False
        if self.loop:
            self.loop.call_soon_threadsafe(self._close_ws)
    
    def _close_ws(self):
        if self.ws:
            asyncio.create_task(self.ws.close())
    
    def _run_async(self, ws_url: str, api_token: str):
        """Run async WebSocket connection"""
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(self._connect_loop(ws_url, api_token))
    
    async def _connect_loop(self, ws_url: str, api_token: str):
        """Connection loop with auto-reconnect"""
        url = f"{ws_url}?token={api_token}"
        
        while self.running:
            try:
                self.on_status("connecting", "Connecting...")
                # Increase max_size to 10MB to allow large screenshot messages
                async with websockets.connect(url, max_size=10 * 1024 * 1024) as ws:
                    self.ws = ws
                    self.on_status("connected", "Connected")
                    
                    async for message in ws:
                        if not self.running:
                            break
                        await self._handle_message(message)
                        
            except websockets.exceptions.ConnectionClosed:
                self.on_status("disconnected", "Connection closed")
            except Exception as e:
                self.on_error(str(e))
                self.on_status("error", f"Error: {str(e)[:30]}")
            
            if self.running:
                self.on_status("reconnecting", "Reconnecting in 5s...")
                await asyncio.sleep(5)
        
        self.on_status("disconnected", "Disconnected")
    
    async def _handle_message(self, message):
        """Handle incoming WebSocket message"""
        try:
            if isinstance(message, bytes):
                # Binary data (PDF chunk)
                self._current_file_data += message
                logger.debug(f"Received binary chunk: {len(message)} bytes")
            else:
                # JSON message
                logger.info(f"Received message: {message[:200]}..." if len(message) > 200 else f"Received message: {message}")
                data = json.loads(message)
                msg_type = data.get("type", "")
                logger.info(f"Message type: {msg_type}")
                
                if msg_type == "start_file":
                    self._current_file_data = b""
                    self._current_metadata = data.get("metadata", {})
                    logger.info(f"Started receiving file: {self._current_metadata.get('orderId', 'unknown')}")
                    
                elif msg_type == "end_file":
                    # Save PDF and create order
                    if self._current_metadata and self._current_file_data:
                        order_id = self._current_metadata.get("orderId", "unknown")
                        print(f"[WS] Saving PDF for order: {order_id} ({len(self._current_file_data)} bytes)")
                        file_path = self._save_pdf(order_id, self._current_file_data)
                        
                        # Check if we have a pending screenshot for this order
                        screenshot_path = self._pending_screenshots.pop(order_id, None)
                        
                        order = PrintOrder.from_websocket(
                            {"metadata": self._current_metadata},
                            file_path,
                            screenshot_path
                        )
                        print(f"[WS] Order received: {order.order_id} - {order.student_name}")
                        self.on_order(order)
                    else:
                        print(f"[WS] end_file but no data! metadata={self._current_metadata is not None}, data_len={len(self._current_file_data)}")
                    
                    self._current_file_data = b""
                    self._current_metadata = None
                    
                elif msg_type == "chunk":
                    # Base64 encoded chunk
                    chunk_data = data.get("data", "")
                    if chunk_data:
                        self._current_file_data += base64.b64decode(chunk_data)
                
                elif msg_type == "metadata":
                    # Standalone metadata message 
                    self._current_metadata = data.get("data", {})
                    logger.info(f"Received metadata for: {self._current_metadata.get('orderId', 'unknown')}")
                
                elif msg_type == "screenshot":
                    # Payment screenshot received
                    logger.info("*** SCREENSHOT MESSAGE RECEIVED ***")
                    order_id = data.get("order_id", "unknown")
                    screenshot_data = data.get("data", "")
                    logger.info(f"Screenshot order_id: {order_id}")
                    logger.info(f"Screenshot data length: {len(screenshot_data)} chars")
                    if screenshot_data:
                        try:
                            screenshot_bytes = base64.b64decode(screenshot_data)
                            logger.info(f"Decoded screenshot: {len(screenshot_bytes)} bytes")
                            screenshot_path = self._save_screenshot(order_id, screenshot_bytes)
                            logger.info(f"Screenshot saved to: {screenshot_path}")
                            self._pending_screenshots[order_id] = screenshot_path
                            logger.info(f"Payment screenshot received for order: {order_id}")
                            if self.on_screenshot:
                                logger.info("Calling on_screenshot callback...")
                                self.on_screenshot(order_id, screenshot_path)
                                logger.info("on_screenshot callback completed")
                            else:
                                logger.warning("on_screenshot callback is None!")
                        except Exception as e:
                            logger.error(f"ERROR decoding/saving screenshot: {e}")
                            import traceback
                            logger.error(traceback.format_exc())
                    else:
                        logger.warning("Screenshot data is empty!")
                
                else:
                    logger.warning(f"Unknown message type: {msg_type}")
                        
        except Exception as e:
            logger.error(f"Message handling error: {e}")
            import traceback
            logger.error(traceback.format_exc())
    
    def _save_pdf(self, order_id: str, data: bytes) -> str:
        """Save PDF file to disk"""
        ensure_dirs()
        file_path = os.path.join(PDF_DIR, f"{order_id}.pdf")
        with open(file_path, "wb") as f:
            f.write(data)
        return file_path
    
    def _save_screenshot(self, order_id: str, data: bytes) -> str:
        """Save payment screenshot to disk, compressing if exceeds 10MB"""
        ensure_dirs()
        file_path = os.path.join(SCREENSHOT_DIR, f"{order_id}_payment.jpg")
        
        MAX_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
        TARGET_SIZE_BYTES = 9 * 1024 * 1024  # 9 MB (safety margin)
        
        # If image is under 10MB, save as-is
        if len(data) <= MAX_SIZE_BYTES:
            with open(file_path, "wb") as f:
                f.write(data)
            logger.info(f"Screenshot saved ({len(data) / 1024 / 1024:.2f} MB): {file_path}")
            return file_path
        
        # Need to compress
        logger.info(f"Screenshot too large ({len(data) / 1024 / 1024:.2f} MB), compressing...")
        
        try:
            from PIL import Image
            import io
            
            # Load image from bytes
            img = Image.open(io.BytesIO(data))
            
            # Convert to RGB if necessary (for JPEG)
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            original_width, original_height = img.size
            
            # Try reducing quality first (from 85 down to 10)
            for quality in range(85, 5, -10):
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG', quality=quality, optimize=True)
                compressed_data = buffer.getvalue()
                
                logger.debug(f"Quality {quality}: {len(compressed_data) / 1024 / 1024:.2f} MB")
                
                if len(compressed_data) <= TARGET_SIZE_BYTES:
                    with open(file_path, "wb") as f:
                        f.write(compressed_data)
                    logger.info(f"Compressed to {len(compressed_data) / 1024 / 1024:.2f} MB (quality={quality})")
                    return file_path
            
            # If quality reduction wasn't enough, also reduce dimensions
            for scale in [0.8, 0.7, 0.6, 0.5, 0.4, 0.3]:
                new_width = int(original_width * scale)
                new_height = int(original_height * scale)
                
                resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                
                buffer = io.BytesIO()
                resized_img.save(buffer, format='JPEG', quality=70, optimize=True)
                compressed_data = buffer.getvalue()
                
                logger.debug(f"Scale {int(scale*100)}% ({new_width}x{new_height}): {len(compressed_data) / 1024 / 1024:.2f} MB")
                
                if len(compressed_data) <= TARGET_SIZE_BYTES:
                    with open(file_path, "wb") as f:
                        f.write(compressed_data)
                    logger.info(f"Compressed to {len(compressed_data) / 1024 / 1024:.2f} MB (scale={int(scale*100)}%)")
                    return file_path
            
            # Last resort: aggressive compression
            small_img = img.resize((original_width // 4, original_height // 4), Image.Resampling.LANCZOS)
            buffer = io.BytesIO()
            small_img.save(buffer, format='JPEG', quality=50, optimize=True)
            compressed_data = buffer.getvalue()
            
            with open(file_path, "wb") as f:
                f.write(compressed_data)
            logger.info(f"Aggressively compressed to {len(compressed_data) / 1024 / 1024:.2f} MB")
            return file_path
            
        except Exception as e:
            logger.error(f"Compression failed: {e}, saving original")
            with open(file_path, "wb") as f:
                f.write(data)
            return file_path
