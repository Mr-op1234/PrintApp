"""API service for notifications"""
import requests

def send_complete_notification(base_url: str, api_token: str, order_id: str, 
                                fcm_token: str, student_name: str, total_pages: int) -> bool:
    """Send print complete notification to student"""
    if not fcm_token:
        print(f"No FCM token for order {order_id}")
        return False
    
    try:
        url = f"{base_url}/api/notify/complete?token={api_token}"
        response = requests.post(url, data={
            "order_id": order_id,
            "fcm_token": fcm_token,
            "student_name": student_name,
            "total_pages": str(total_pages),
        }, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            return data.get("success", False)
        return False
    except Exception as e:
        print(f"Notification error: {e}")
        return False

def send_rejection_notification(base_url: str, api_token: str, order_id: str,
                                 fcm_token: str, student_name: str, reason: str) -> bool:
    """Send rejection notification to student"""
    if not fcm_token:
        print(f"No FCM token for order {order_id}")
        return False
    
    try:
        url = f"{base_url}/api/notify/rejected?token={api_token}"
        response = requests.post(url, data={
            "order_id": order_id,
            "fcm_token": fcm_token,
            "student_name": student_name,
            "reason": reason,
        }, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            return data.get("success", False)
        return False
    except Exception as e:
        print(f"Rejection notification error: {e}")
        return False

def check_server_status(base_url: str) -> bool:
    """Check if server is online"""
    try:
        response = requests.get(f"{base_url}/api/status", timeout=5)
        return response.status_code == 200
    except:
        return False

def toggle_service_pause(base_url: str, api_token: str, pause: bool) -> bool:
    """Toggle service pause state on server"""
    try:
        url = f"{base_url}/api/service/pause?token={api_token}"
        response = requests.post(url, data={"paused": str(pause).lower()}, timeout=10)
        if response.status_code == 200:
            return response.json().get("success", False)
        return False
    except Exception as e:
        print(f"Pause toggle error: {e}")
        return False

def get_service_status(base_url: str, api_token: str) -> dict:
    """Get current service status including pause state"""
    try:
        url = f"{base_url}/api/service/status?token={api_token}"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            return response.json()
        return {"paused": False}
    except:
        return {"paused": False}
