"""SQLite database for order persistence"""
import sqlite3
import os
import logging
from datetime import datetime
from typing import List, Optional
from models import PrintOrder
from config import DB_FILE, ensure_dirs

logger = logging.getLogger(__name__)

# Define column order explicitly for consistent reading
COLUMN_ORDER = """
    order_id, student_name, student_id, phone, total_pages, paper_size,
    print_type, print_side, copies, total_cost, transaction_id, payment_amount,
    local_file_path, received_at, completed_at, status, fcm_token,
    binding_type, payment_screenshot_path, additional_info
"""

def init_db():
    """Initialize database tables"""
    ensure_dirs()
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Create table with original schema
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            order_id TEXT PRIMARY KEY,
            student_name TEXT,
            student_id TEXT,
            phone TEXT,
            total_pages INTEGER,
            paper_size TEXT,
            print_type TEXT,
            print_side TEXT,
            copies INTEGER,
            total_cost REAL,
            transaction_id TEXT,
            payment_amount REAL,
            local_file_path TEXT,
            received_at TEXT,
            completed_at TEXT,
            status TEXT DEFAULT 'pending',
            fcm_token TEXT
        )
    """)
    
    # Migration: Add new columns if they don't exist
    try:
        cursor.execute("ALTER TABLE orders ADD COLUMN binding_type TEXT DEFAULT 'NONE'")
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    try:
        cursor.execute("ALTER TABLE orders ADD COLUMN payment_screenshot_path TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    try:
        cursor.execute("ALTER TABLE orders ADD COLUMN additional_info TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    conn.commit()
    conn.close()

def save_order(order: PrintOrder):
    """Save order to database"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT OR REPLACE INTO orders 
        (order_id, student_name, student_id, phone, total_pages, paper_size,
         print_type, print_side, copies, total_cost, transaction_id, 
         payment_amount, local_file_path, received_at, completed_at, status, fcm_token,
         binding_type, payment_screenshot_path, additional_info)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        order.order_id, order.student_name, order.student_id, order.phone,
        order.total_pages, order.paper_size, order.print_type, order.print_side,
        order.copies, order.total_cost, order.transaction_id, 
        order.payment_amount, order.local_file_path, order.received_at.isoformat(),
        order.completed_at.isoformat() if order.completed_at else None,
        order.status, order.fcm_token,
        order.binding_type, order.payment_screenshot_path, order.additional_info
    ))
    
    conn.commit()
    conn.close()

def get_pending_orders() -> List[PrintOrder]:
    """Get all pending orders"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Use explicit column order
    cursor.execute(f"SELECT {COLUMN_ORDER} FROM orders WHERE status = 'pending' ORDER BY received_at ASC")
    rows = cursor.fetchall()
    conn.close()
    
    return [_row_to_order(row) for row in rows]

def get_completed_orders(limit: int = 50) -> List[PrintOrder]:
    """Get completed orders"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Use explicit column order
    cursor.execute(
        f"SELECT {COLUMN_ORDER} FROM orders WHERE status = 'completed' ORDER BY completed_at DESC LIMIT ?",
        (limit,)
    )
    rows = cursor.fetchall()
    conn.close()
    
    return [_row_to_order(row) for row in rows]

def update_order_status(order_id: str, status: str, completed_at: datetime = None):
    """Update order status"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    if completed_at:
        cursor.execute(
            "UPDATE orders SET status = ?, completed_at = ? WHERE order_id = ?",
            (status, completed_at.isoformat(), order_id)
        )
    else:
        cursor.execute(
            "UPDATE orders SET status = ? WHERE order_id = ?",
            (status, order_id)
        )
    
    conn.commit()
    conn.close()

def delete_order(order_id: str):
    """Delete order from database"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM orders WHERE order_id = ?", (order_id,))
    conn.commit()
    conn.close()

def update_screenshot_path(order_id: str, screenshot_path: str):
    """Update order with screenshot path (called when screenshot arrives after order)"""
    logger.info(f"update_screenshot_path called: order_id={order_id}, path={screenshot_path}")
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # First check if order exists
    cursor.execute("SELECT order_id, payment_screenshot_path FROM orders WHERE order_id = ?", (order_id,))
    existing = cursor.fetchone()
    logger.info(f"Existing order: {existing}")
    
    cursor.execute(
        "UPDATE orders SET payment_screenshot_path = ? WHERE order_id = ?",
        (screenshot_path, order_id)
    )
    rows_affected = cursor.rowcount
    logger.info(f"UPDATE affected {rows_affected} rows")
    
    conn.commit()
    conn.close()
    logger.info(f"Updated screenshot path for order {order_id} - SUCCESS")

def _row_to_order(row) -> PrintOrder:
    """Convert database row to PrintOrder - uses explicit column order"""
    # Column order (from COLUMN_ORDER):
    # 0: order_id, 1: student_name, 2: student_id, 3: phone, 4: total_pages,
    # 5: paper_size, 6: print_type, 7: print_side, 8: copies, 9: total_cost,
    # 10: transaction_id, 11: payment_amount, 12: local_file_path, 13: received_at,
    # 14: completed_at, 15: status, 16: fcm_token, 17: binding_type,
    # 18: payment_screenshot_path, 19: additional_info
    
    # Parse received_at safely
    try:
        received_at = datetime.fromisoformat(row[13]) if row[13] else datetime.now()
    except (ValueError, TypeError):
        received_at = datetime.now()
    
    # Parse completed_at safely
    try:
        completed_at = datetime.fromisoformat(row[14]) if row[14] else None
    except (ValueError, TypeError):
        completed_at = None
    
    return PrintOrder(
        order_id=row[0],
        student_name=row[1] or "Unknown",
        student_id=row[2] or "",
        phone=row[3] or "",
        total_pages=row[4] or 0,
        paper_size=row[5] or "A4",
        print_type=row[6] or "BW",
        print_side=row[7] or "SINGLE",
        copies=row[8] or 1,
        binding_type=row[17] or 'NONE',
        total_cost=row[9] or 0.0,
        transaction_id=row[10],
        payment_amount=row[11],
        local_file_path=row[12] or "",
        payment_screenshot_path=row[18] if len(row) > 18 else None,
        additional_info=row[19] if len(row) > 19 else '',
        received_at=received_at,
        completed_at=completed_at,
        status=row[15] or "pending",
        fcm_token=row[16],
    )
