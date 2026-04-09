import firebase_admin
from firebase_admin import credentials, messaging
import os
from dotenv import load_dotenv

load_dotenv()

# Initialize Firebase Admin SDK
try:
    firebase_credentials_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
    cred = credentials.Certificate(firebase_credentials_path)
    firebase_admin.initialize_app(cred)
    print(f"Firebase initialized successfully from {firebase_credentials_path}")
except Exception as e:
    print(f"Firebase initialization error: {e}")

def send_tap_notification(fcm_token: str, nfc_id: str, notification_id: str, student_name: str):
    """Send push notification to student when NFC is tapped"""
    try:
        title = "NFC Card Tapped"
        body = "Your card was scanned on a bus. Accept or Deny this payment?"
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "nfc_tap",
                "notification_id": notification_id,
                "nfc_id": nfc_id,
                "student_name": student_name,
                "action_required": "true",
                "title": title,
                "body": body,
            },
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                ttl=120,
                notification=messaging.AndroidNotification(
                    title=title,
                    body=body,
                    channel_id="nfc_taps",
                    priority="max",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        content_available=True,
                    )
                )
            )
        )
        
        response = messaging.send(message)
        print(f"Successfully sent notification: {response}")
        return True
    except Exception as e:
        print(f"Error sending notification: {e}")
        return False

def send_blocked_nfc_alert(fcm_token: str):
    """Send alert when blocked NFC is used"""
    try:
        title = "Blocked NFC Used"
        body = "Your blocked NFC card was used. Take action immediately!"
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "blocked_nfc_alert",
                "action_required": "true",
                "title": title,
                "body": body,
            },
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    title=title,
                    body=body,
                    channel_id="nfc_taps",
                    priority="high",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        content_available=True,
                    )
                ),
            ),
        )
        
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"Error sending blocked NFC alert: {e}")
        return False

def send_expired_notification_alert(fcm_token: str, nfc_id: str):
    """Send alert when notification expired and was auto-accepted"""
    try:
        title = "NFC Payment Auto-Accepted"
        body = "Your NFC was used but you did not respond in time. Payment was auto-accepted."
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "expired_notification",
                "nfc_id": nfc_id,
                "action_required": "true",
                "title": title,
                "body": body,
            },
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    title=title,
                    body=body,
                    channel_id="nfc_taps",
                    priority="high",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        content_available=True,
                    )
                ),
            ),
        )
        
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"Error sending expired notification alert: {e}")
        return False
