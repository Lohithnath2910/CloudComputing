# Environment Configuration Guide

This project uses environment variables for all sensitive and configurable settings. Follow this guide to set up your environment properly.

## Backend Setup (cn_backend/)

### 1. Copy the Environment Template
```bash
cd cn_backend
cp .env.example .env
```

### 2. Configure Your `.env` File

The `.env` file contains:

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL/Aiven connection string | `postgres://user:pass@host:port/db?sslmode=require` |
| `SECRET_KEY` | JWT secret key (change this!) | `your_secret_key_here` |
| `ALGORITHM` | JWT algorithm | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Token expiration time | `60` |
| `FIREBASE_CREDENTIALS_PATH` | Path to Firebase service account JSON | `firebase-service-account.json` |
| `BASE_FARE` | Default bus fare | `20.0` |
| `AUTO_EXPIRE_INTERVAL` | Auto-expire notification check interval (seconds) | `30` |
| `TAP_NOTIFICATION_EXPIRY_DURATION` | How long to keep tap notifications (seconds) | `300` |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | `http://localhost:3000,http://localhost:8100` |
| `DEBUG` | Enable debug mode | `false` |
| `BACKEND_URL` | Backend server URL | `http://localhost:8000` |
| `BACKEND_PORT` | Backend server port | `8000` |

### 3. Firebase Setup

1. Create a Firebase project at https://firebase.google.com
2. Download your service account JSON from Firebase Console → Project Settings → Service Accounts
3. Save it as `firebase-service-account.json` in `cn_backend/` directory
4. **Important**: Never commit this file to git (it's in `.gitignore`)

### 4. Database Setup (Aiven Cloud)

Our example uses Aiven Cloud PostgreSQL. Update `DATABASE_URL` with your Aiven credentials:
```
postgres://username:password@your-aiven-cluster.aivencloud.com:20137/defaultdb?sslmode=require
```
Get your credentials from the Aiven Cloud Console → Database connections.

### 5. Install Dependencies
```bash
pip install -r requirements.txt
```

### 6. Run Backend
```bash
python main.py
# or with uvicorn
uvicorn main:app --reload
```

---

## Frontend Setup (cn_project/)

### 1. Copy the Environment Template
```bash
cd cn_project
cp .env.example .env
```

### 2. Configure Your `.env` File

The `.env` file contains:

| Variable | Description | Example |
|----------|-------------|---------|
| `API_BASE_URL` | Backend API endpoint | `http://localhost:8000` |
| `FIREBASE_DEBUG` | Firebase debug mode | `true` |
| `ENABLE_NFC_TAPPING` | Enable NFC functionality | `true` |
| `ENABLE_NOTIFICATIONS` | Enable push notifications | `true` |
| `ENABLE_DEBUG_LOGGING` | Enable app logging | `true` |

### 3. Firebase Setup (Google Services)

**Android:**
1. Download `google-services.json` from Firebase Console
2. Place it at: `cn_project/android/app/`

**iOS:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it at: `cn_project/ios/Runner/`

### 4. Install Flutter Dependencies
```bash
flutter pub get
```

### 5. Run Frontend
```bash
flutter run
```

---

## Environment-Specific Configuration

### Development
- Use `localhost` URLs
- Set `DEBUG=true`
- Use development Firebase projects

### Production
- Use production Firebase projects
- Use production database URL
- Set `DEBUG=false`
- Use production backend URL (HTTPS)
- Update `ALLOWED_ORIGINS` with production domains

---

## Security Best Practices

⚠️ **IMPORTANT:**
- ✅ `.env` files are in `.gitignore` - they won't be committed
- ✅ Never share or commit `.env` files
- ✅ Never commit `firebase-service-account.json`
- ✅ Use strong `SECRET_KEY` for production
- ✅ Rotate `SECRET_KEY` periodically
- ✅ Use HTTPS in production

### For Production Deployment:
1. Set environment variables on your hosting platform (AWS, Heroku, etc.)
2. Do NOT commit real `.env` files
3. Use separate service accounts for different environments
4. Enable Firebase authentication security rules

---

## Troubleshooting

### Backend won't start
```bash
# Check if all required env variables are set
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.environ)"

# Verify database connection
python -c "from database import engine; print(engine)"
```

### Frontend can't reach backend
```
- Check API_BASE_URL is correct
- Ensure backend is running
- Check CORS settings in ALLOWED_ORIGINS
- Verify no firewall blocking ports
```

### Firebase not working
```
- Verify firebase-service-account.json path is correct
- Check JSON file is valid
- Ensure Firebase project is active
```

---

## Next Steps

1. Copy `.env.example` to `.env` for both backend and frontend
2. Fill in your Aiven cloud credentials
3. Add your Firebase credentials
4. Run `pip install -r requirements.txt` 
5. Run `flutter pub get`
6. Start developing! 🚀
