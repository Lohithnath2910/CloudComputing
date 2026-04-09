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
        message = messaging.Message(
            notification=messaging.Notification(
                title="🚌 NFC Card Tapped",
                body=f"Your card was scanned on a bus. Accept or Deny this payment?"
            ),
            data={
                "type": "nfc_tap",
                "notification_id": notification_id,
                "nfc_id": nfc_id,
                "action_required": "true"
            },
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='nfc_taps',
                    priority='high',
                    default_sound=True
                )
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True
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
        message = messaging.Message(
            notification=messaging.Notification(
                title="⚠️ Blocked NFC Used",
                body="Your blocked NFC card was used. Take action immediately!"
            ),
            data={
                "type": "blocked_nfc_alert",
                "action_required": "true"
            },
            token=fcm_token
        )
        
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"Error sending blocked NFC alert: {e}")
        return False

def send_expired_notification_alert(fcm_token: str, nfc_id: str):
    """Send alert when notification expired and was auto-accepted"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="⚠️ NFC Payment Auto-Accepted",
                body="Your NFC was used but you didn't respond in time. Payment was auto-accepted. Block your NFC if this wasn't you."
            ),
            data={
                "type": "expired_notification",
                "nfc_id": nfc_id,
                "action_required": "true"
            },
            token=fcm_token
        )
        
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"Error sending expired notification alert: {e}")
        return False
