from fastapi import WebSocket
from typing import Optional

class ConnectionManager:
    def __init__(self):
        # We assume one active Xerox station for simplicity
        # In a larger app, this would be a dict of shop_id -> websocket
        self.active_xerox: Optional[WebSocket] = None
        
        # Service status - can be paused by Xerox Manager
        self._accepting_orders: bool = True

    @property
    def is_xerox_online(self) -> bool:
        """Check if xerox station is connected."""
        return self.active_xerox is not None
    
    @property
    def is_accepting_orders(self) -> bool:
        """Check if service is accepting new orders."""
        return self._accepting_orders and self.is_xerox_online
    
    def set_accepting_orders(self, accepting: bool):
        """Toggle service availability (called by Xerox Manager)."""
        self._accepting_orders = accepting
    
    def get_service_status(self) -> dict:
        """Get full service status for health checks."""
        return {
            "xerox_online": self.is_xerox_online,
            "accepting_orders": self.is_accepting_orders,
            "paused": not self._accepting_orders,
        }

    async def connect_xerox(self, websocket: WebSocket):
        await websocket.accept()
        self.active_xerox = websocket
        # Auto-resume when xerox connects
        self._accepting_orders = True

    def disconnect_xerox(self):
        self.active_xerox = None

    async def stream_chunk_to_xerox(self, data: bytes, metadata: dict = None):
        """
        Stream raw bytes to the connected xerox station.
        If metadata is provided, send it first as a header frame.
        """
        if self.active_xerox:
            if metadata:
                # Send metadata as a separate JSON frame first
                await self.active_xerox.send_json({"type": "metadata", "data": metadata})
            
            # Send file data as binary frame
            await self.active_xerox.send_bytes(data)
            return True
        return False
    
    async def send_file_start(self, filename: str, metadata: dict):
        if self.active_xerox:
            await self.active_xerox.send_json({
                "type": "start_file",
                "filename": filename,
                "metadata": metadata
            })
            return True
        return False

    async def send_file_end(self):
        if self.active_xerox:
            await self.active_xerox.send_json({"type": "end_file"})
            return True
        return False
    
    async def send_screenshot(self, order_id: str, data: bytes):
        """Send payment screenshot as base64 encoded JSON message."""
        if self.active_xerox:
            import base64
            await self.active_xerox.send_json({
                "type": "screenshot",
                "order_id": order_id,
                "data": base64.b64encode(data).decode('utf-8')
            })
            return True
        return False

manager = ConnectionManager()
