"""
Firebase Cloud Messaging (FCM) Service for sending push notifications.
Used to notify students when their print job is complete.
"""
import os
import json
from typing import Optional, Dict, Any

# Initialize Firebase only if credentials are available
_firebase_app = None
_messaging = None

def _initialize_firebase():
    """Initialize Firebase Admin SDK with service account credentials."""
    global _firebase_app, _messaging
    
    if _firebase_app is not None:
        return True
    
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
        
        # Check for credentials file path in environment
        creds_path = os.environ.get("FIREBASE_CREDENTIALS_PATH")
        creds_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
        
        if creds_path and os.path.exists(creds_path):
            cred = credentials.Certificate(creds_path)
        elif creds_json:
            # Parse JSON from environment variable (for HuggingFace Spaces)
            creds_dict = json.loads(creds_json)
            cred = credentials.Certificate(creds_dict)
        else:
            print("Firebase credentials not found. Push notifications disabled.")
            return False
        
        _firebase_app = firebase_admin.initialize_app(cred)
        _messaging = messaging
        print("Firebase initialized successfully for push notifications.")
        return True
        
    except Exception as e:
        print(f"Firebase initialization failed: {e}")
        return False


def send_print_complete_notification(
    fcm_token: str,
    order_id: str,
    student_name: str,
    total_pages: int = 0,
) -> bool:
    """
    Send push notification to student when their print job is complete.
    
    Args:
        fcm_token: The student's device FCM token
        order_id: The order ID
        student_name: Student's name for personalization
        total_pages: Number of pages printed
    
    Returns:
        True if notification sent successfully, False otherwise
    """
    print(f"=== FCM DEBUG [FCM Service] ===")
    print(f"Attempting to send notification for order: {order_id}")
    print(f"FCM Token present: {bool(fcm_token)}")
    if fcm_token:
        print(f"FCM Token (first 50 chars): {fcm_token[:50]}...")
    
    if not _initialize_firebase():
        print(f"ERROR: Firebase initialization failed!")
        return False
    
    if not fcm_token:
        print(f"ERROR: No FCM token for order {order_id}")
        return False
    
    print(f"Firebase initialized. Sending notification...")
    
    try:
        # Construct notification message
        message = _messaging.Message(
            notification=_messaging.Notification(
                title="🖨️ Print Complete!",
                body=f"Hi {student_name}, your print order ({total_pages} pages) is ready for pickup!",
            ),
            data={
                "order_id": order_id,
                "type": "print_complete",
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            },
            token=fcm_token,
            android=_messaging.AndroidConfig(
                priority="high",
                notification=_messaging.AndroidNotification(
                    icon="ic_launcher",
                    color="#6366F1",
                    channel_id="print_orders",
                    sound="default",
                ),
            ),
            apns=_messaging.APNSConfig(
                payload=_messaging.APNSPayload(
                    aps=_messaging.Aps(
                        alert=_messaging.ApsAlert(
                            title="🖨️ Print Complete!",
                            body=f"Hi {student_name}, your print order ({total_pages} pages) is ready for pickup!",
                        ),
                        badge=1,
                        sound="default",
                    ),
                ),
            ),
        )
        
        # Send the message
        response = _messaging.send(message)
        print(f"Notification sent successfully for order {order_id}: {response}")
        return True
        
    except Exception as e:
        print(f"Failed to send notification for order {order_id}: {e}")
        return False


def send_order_rejected_notification(
    fcm_token: str,
    order_id: str,
    student_name: str,
    reason: str = "Order was not processed",
) -> bool:
    """
    Send push notification to student when their print order is rejected/deleted.
    
    Args:
        fcm_token: The student's device FCM token
        order_id: The order ID
        student_name: Student's name for personalization
        reason: Reason for rejection
    
    Returns:
        True if notification sent successfully, False otherwise
    """
    print(f"=== FCM DEBUG [FCM Service - Rejection] ===")
    print(f"Attempting to send rejection notification for order: {order_id}")
    print(f"FCM Token present: {bool(fcm_token)}")
    if fcm_token:
        print(f"FCM Token (first 50 chars): {fcm_token[:50]}...")
    
    if not _initialize_firebase():
        print(f"ERROR: Firebase initialization failed!")
        return False
    
    if not fcm_token:
        print(f"ERROR: No FCM token for order {order_id}")
        return False
    
    print(f"Firebase initialized. Sending rejection notification...")
    
    try:
        # Construct notification message
        message = _messaging.Message(
            notification=_messaging.Notification(
                title="❌ Print Order Rejected",
                body=f"Hi {student_name}, your print order was not processed. Reason: {reason}",
            ),
            data={
                "order_id": order_id,
                "type": "print_rejected",
                "reason": reason,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            },
            token=fcm_token,
            android=_messaging.AndroidConfig(
                priority="high",
                notification=_messaging.AndroidNotification(
                    icon="ic_launcher",
                    color="#EF4444",
                    channel_id="print_orders",
                    sound="default",
                ),
            ),
            apns=_messaging.APNSConfig(
                payload=_messaging.APNSPayload(
                    aps=_messaging.Aps(
                        alert=_messaging.ApsAlert(
                            title="❌ Print Order Rejected",
                            body=f"Hi {student_name}, your print order was not processed. Reason: {reason}",
                        ),
                        badge=1,
                        sound="default",
                    ),
                ),
            ),
        )
        
        # Send the message
        response = _messaging.send(message)
        print(f"Rejection notification sent successfully for order {order_id}: {response}")
        return True
        
    except Exception as e:
        print(f"Failed to send rejection notification for order {order_id}: {e}")
        return False


def send_order_status_notification(
    fcm_token: str,
    order_id: str,
    status: str,
    message: str,
) -> bool:
    """
    Send generic order status update notification.
    
    Args:
        fcm_token: The student's device FCM token
        order_id: The order ID
        status: Status code (e.g., 'printing', 'error', 'cancelled')
        message: Human-readable status message
    
    Returns:
        True if notification sent successfully, False otherwise
    """
    if not _initialize_firebase():
        return False
    
    if not fcm_token:
        return False
    
    try:
        # Status-specific icons
        status_icons = {
            "printing": "🖨️",
            "error": "❌",
            "cancelled": "🚫",
            "queued": "📋",
        }
        icon = status_icons.get(status, "📢")
        
        message_obj = _messaging.Message(
            notification=_messaging.Notification(
                title=f"{icon} Order Update",
                body=message,
            ),
            data={
                "order_id": order_id,
                "type": "status_update",
                "status": status,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            },
            token=fcm_token,
        )
        
        _messaging.send(message_obj)
        return True
        
    except Exception as e:
        print(f"Failed to send status notification for order {order_id}: {e}")
        return False
