import firebase_admin
from firebase_admin import credentials, messaging
import os
import logging

logger = logging.getLogger(__name__)

def init_firebase():
    try:
        # Check if already initialized
        firebase_admin.get_app()
    except ValueError:
        # Initialize
        cert_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "firebase-adminsdk.json")
        if os.path.exists(cert_path):
            try:
                cred = credentials.Certificate(cert_path)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin: {e}")
        else:
            logger.warning(f"Firebase Service Account file not found at {cert_path}")

def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None):
    if not fcm_token:
        return False
        
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending message: {e}")
        return False
