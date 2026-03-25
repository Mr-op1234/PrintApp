"""
Transaction Cache for duplicate detection (in-memory, stateless)
Clears on server restart - final validation is done by Manager App
"""
import time
from threading import Lock
from typing import Optional, Tuple

class TransactionCache:
    """
    In-memory LRU cache for recently seen transaction IDs.
    - Max 1000 entries
    - 15-minute TTL
    - Thread-safe
    """
    
    def __init__(self, max_size: int = 1000, ttl_seconds: int = 900):
        self.max_size = max_size
        self.ttl_seconds = ttl_seconds
        self._cache: dict = {}  # txn_id -> (timestamp, order_id)
        self._lock = Lock()
    
    def _cleanup_expired(self):
        """Remove expired entries."""
        now = time.time()
        expired_keys = [
            k for k, v in self._cache.items()
            if now - v[0] > self.ttl_seconds
        ]
        for key in expired_keys:
            del self._cache[key]
    
    def _evict_oldest(self):
        """Remove oldest entries if cache is full."""
        if len(self._cache) >= self.max_size:
            # Sort by timestamp and remove oldest 10%
            sorted_items = sorted(self._cache.items(), key=lambda x: x[1][0])
            to_remove = max(1, len(sorted_items) // 10)
            for key, _ in sorted_items[:to_remove]:
                del self._cache[key]
    
    def check_and_add(self, txn_id: str, order_id: str) -> Tuple[bool, Optional[str]]:
        """
        Check if transaction ID exists and add if new.
        
        Returns: (is_duplicate, existing_order_id)
        """
        if not txn_id:
            return False, None
        
        normalized_id = txn_id.strip().upper()
        
        with self._lock:
            self._cleanup_expired()
            
            # Check if exists
            if normalized_id in self._cache:
                existing_order = self._cache[normalized_id][1]
                return True, existing_order
            
            # Add new entry
            self._evict_oldest()
            self._cache[normalized_id] = (time.time(), order_id)
            return False, None
    
    def exists(self, txn_id: str) -> bool:
        """Check if transaction ID exists in cache."""
        if not txn_id:
            return False
        
        normalized_id = txn_id.strip().upper()
        
        with self._lock:
            self._cleanup_expired()
            return normalized_id in self._cache
    
    def get_stats(self) -> dict:
        """Get cache statistics."""
        with self._lock:
            self._cleanup_expired()
            return {
                "size": len(self._cache),
                "max_size": self.max_size,
                "ttl_seconds": self.ttl_seconds,
            }

# Global cache instance
transaction_cache = TransactionCache(max_size=1000, ttl_seconds=900)
