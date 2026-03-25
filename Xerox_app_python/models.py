"""Order model"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class PrintOrder:
    order_id: str
    student_name: str
    student_id: str
    phone: str
    total_pages: int
    paper_size: str
    print_type: str
    print_side: str
    copies: int
    binding_type: str  # NONE, SPIRAL, SOFT
    total_cost: float
    transaction_id: Optional[str]
    payment_amount: Optional[float]
    local_file_path: str
    payment_screenshot_path: Optional[str]  # Path to payment screenshot image
    additional_info: Optional[str]  # Optional additional info from student
    received_at: datetime
    completed_at: Optional[datetime] = None
    status: str = "pending"  # pending, completed, error
    fcm_token: Optional[str] = None
    
    @classmethod
    def from_websocket(cls, data: dict, file_path: str, screenshot_path: Optional[str] = None):
        """Create order from WebSocket message"""
        metadata = data.get("metadata", {})
        student = metadata.get("student", {})
        config = metadata.get("config", {})
        payment = metadata.get("payment", {})
        
        total_pages = metadata.get("totalPages") or config.get("totalPages", 0)
        fcm_token = metadata.get("fcm_token") or data.get("fcm_token")
        
        return cls(
            order_id=metadata.get("orderId", data.get("orderId", "UNKNOWN")),
            student_name=student.get("name", "Unknown"),
            student_id=student.get("studentId", ""),
            phone=student.get("phone", ""),
            total_pages=total_pages,
            paper_size=config.get("paperSize", "A4"),
            print_type=config.get("printType", "BW"),
            print_side=config.get("printSide", "SINGLE"),
            copies=config.get("copies", 1),
            binding_type=config.get("bindingType", "NONE"),
            total_cost=float(metadata.get("totalPrice", 0)),
            transaction_id=payment.get("transactionId"),
            payment_amount=float(payment.get("amount", 0)) if payment.get("amount") else None,
            local_file_path=file_path,
            payment_screenshot_path=screenshot_path,
            additional_info=student.get("additionalInfo", ""),
            received_at=datetime.now(),
            fcm_token=fcm_token,
        )
    
    def to_dict(self):
        return {
            "order_id": self.order_id,
            "student_name": self.student_name,
            "student_id": self.student_id,
            "phone": self.phone,
            "total_pages": self.total_pages,
            "paper_size": self.paper_size,
            "print_type": self.print_type,
            "print_side": self.print_side,
            "copies": self.copies,
            "binding_type": self.binding_type,
            "total_cost": self.total_cost,
            "transaction_id": self.transaction_id,
            "payment_amount": self.payment_amount,
            "local_file_path": self.local_file_path,
            "payment_screenshot_path": self.payment_screenshot_path,
            "additional_info": self.additional_info,
            "received_at": self.received_at.isoformat(),
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "status": self.status,
            "fcm_token": self.fcm_token,
        }
