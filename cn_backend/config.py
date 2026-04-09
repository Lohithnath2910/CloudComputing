import os
from dotenv import load_dotenv

load_dotenv()

# Fare Configuration
BASE_FARE = float(os.getenv("BASE_FARE", "20.0"))

# Notification Configuration
AUTO_EXPIRE_INTERVAL = int(os.getenv("AUTO_EXPIRE_INTERVAL", "30"))  # seconds

# Tap Notification Configuration
TAP_NOTIFICATION_EXPIRY_DURATION = int(os.getenv("TAP_NOTIFICATION_EXPIRY_DURATION", "300"))  # 5 minutes

# CORS Configuration
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")

# Debug Mode
DEBUG = os.getenv("DEBUG", "false").lower() == "true"
