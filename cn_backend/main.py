from fastapi import FastAPI, Depends, HTTPException, Body, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
import crud, models, schemas
from database import engine, get_db
from fastapi.security import OAuth2PasswordRequestForm
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from auth import create_access_token, verify_password, get_password_hash, SECRET_KEY, ALGORITHM, oauth2_scheme
import models
import asyncio
from contextlib import asynccontextmanager
from config import AUTO_EXPIRE_INTERVAL, AUTO_EXPIRE_BACKGROUND_ENABLED
from routes.admin import router as admin_router

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="NFC Bus Backend")


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = None
    if AUTO_EXPIRE_BACKGROUND_ENABLED:
        # Startup: Start periodic auto-expire task when enabled by config
        task = asyncio.create_task(background_auto_expire_task())
    yield
    # Shutdown: Cancel background task if it was started
    if task:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

async def background_auto_expire_task():
    """Run auto-expire task in periodic intervals"""
    while True:
        try:
            await asyncio.sleep(AUTO_EXPIRE_INTERVAL)
            db = next(get_db())
            expired_count = crud.auto_expire_old_notifications(db)
            if expired_count > 0:
                print(f"Auto-expired {expired_count} notification(s)")
            db.close()
        except Exception as e:
            print(f"Error in auto-expire task: {e}")

# Update FastAPI app initialization
app = FastAPI(title="NFC Bus Backend", lifespan=lifespan)
app.include_router(admin_router)

def get_current_user_id(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except Exception:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

# Background task to auto-expire notifications
def auto_expire_task(db: Session):
    crud.auto_expire_old_notifications(db)

# ---------------- Students ----------------
@app.post("/students", response_model=schemas.Student)
def create_student(student: schemas.StudentCreate, db: Session = Depends(get_db)):
    try:
        return crud.create_student(db, student)
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Email already exists")

@app.get("/students/me", response_model=schemas.Student)
def get_current_student(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    student = crud.get_student_by_id(db, user_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return student

@app.patch("/students/me/fcm_token")
def update_student_fcm_token(
    token_update: schemas.FcmTokenUpdate, 
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    updated = crud.update_fcm_token(db, user_id, token_update.fcm_token, is_driver=False)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return {"detail": "FCM token updated successfully"}

@app.patch("/students/me/nfc", response_model=schemas.Student)
def register_nfc(
    nfc_update: schemas.NfcUpdate, 
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    try:
        updated_student = crud.update_student_nfc(db, user_id, nfc_update.nfc_id)
        if not updated_student:
            raise HTTPException(status_code=404, detail="User not found")
        return updated_student
    except ValueError as e:
        msg = str(e)
        status_code = 409 if "already registered" in msg else 400
        raise HTTPException(status_code=status_code, detail=msg)

@app.patch("/students/me/block_nfc", response_model=schemas.Student)
def block_nfc(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    student = crud.block_student_nfc(db, user_id)
    if not student:
        raise HTTPException(status_code=404, detail="User not found")
    return student

@app.post("/students/me/tap_notifications/{notification_id}/respond")
def respond_to_tap_notification(
    notification_id: str, 
    response: schemas.TapNotificationResponse,
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    try:
        trip_detail = crud.respond_to_tap_notification(db, notification_id, response.accepted, user_id)
        return {
            "detail": "Response recorded successfully",
            "status": trip_detail.status,
            "accepted": response.accepted
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/students/me/pending_notifications", response_model=list[schemas.PendingNotification])
def get_pending_notifications(
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    # Run auto-expire in background
    background_tasks.add_task(auto_expire_task, db)
    return crud.get_pending_notifications_for_student(db, user_id)

@app.post("/students/me/notifications/{notification_id}/dismiss")
def dismiss_expired_warning(
    notification_id: str,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id)
):
    notification = crud.dismiss_expired_warning(db, notification_id, user_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"detail": "Warning dismissed"}

@app.get("/students/me/trips", response_model=list[schemas.StudentTripSummary])
def get_student_trips(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    return crud.get_student_trips(db, user_id)


@app.get("/students/me/trips/{trip_id}/details", response_model=schemas.StudentTripDetailView)
def get_student_trip_details(
    trip_id: str,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    details = crud.get_student_trip_details(db, user_id, trip_id)
    if not details:
        raise HTTPException(status_code=404, detail="Trip details not found")
    return details

@app.delete("/students/{student_id}")
def delete_student(student_id: str, db: Session = Depends(get_db)):
    student = crud.delete_student(db, student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return {"detail": "Deleted successfully"}

# ---------------- Bus Drivers ----------------
@app.post("/drivers", response_model=schemas.BusDriver)
def create_driver(driver: schemas.BusDriverCreate, db: Session = Depends(get_db)):
    return crud.create_driver(db, driver)

@app.get("/drivers/me", response_model=schemas.BusDriver)
def get_current_driver(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    driver = crud.get_driver_by_id(db, user_id)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    return driver

@app.patch("/drivers/me/fcm_token")
def update_driver_fcm_token(
    token_update: schemas.FcmTokenUpdate, 
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    updated = crud.update_fcm_token(db, user_id, token_update.fcm_token, is_driver=True)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return {"detail": "FCM token updated successfully"}

@app.get("/drivers/me/trips", response_model=list[schemas.Trip])
def get_driver_trips(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    return crud.get_driver_trips(db, user_id)

@app.get("/drivers/me/trips/{trip_id}/details")
def get_driver_trip_details(
    trip_id: str, 
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    trip = crud.get_trip_by_id(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if str(trip.driver_id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    return crud.get_trip_details_with_students(db, trip_id)

@app.delete("/drivers/{driver_id}")
def delete_driver(driver_id: str, db: Session = Depends(get_db)):
    driver = crud.delete_driver(db, driver_id)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    return {"detail": "Deleted successfully"}

# ---------------- Driver Active Trip Management ----------------
@app.post("/drivers/me/trips/active", response_model=schemas.Trip)
def create_and_start_active_trip(
    body: schemas.ActiveTripCreateRequest,
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id)
):
    driver = crud.get_driver_by_id(db, user_id)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    
    active_trip = crud.get_active_trip_for_driver(db, user_id)
    if active_trip:
        raise HTTPException(status_code=400, detail="You already have an active trip. Please end it first.")
    
    trip_name = body.name or "Trip"

    try:
        resolved_bus_id = crud.resolve_bus_for_new_active_trip(
            db,
            user_id,
            str(body.bus_id) if body.bus_id else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    trip_data = schemas.TripCreate(driver_id=user_id, name=trip_name, bus_id=resolved_bus_id)
    trip = crud.create_trip(db, trip_data)
    trip = crud.start_trip(db, str(trip.id))
    return trip

@app.get("/drivers/me/trips/active", response_model=schemas.Trip)
def get_active_trip(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    trip = crud.get_active_trip_for_driver(db, user_id)
    if not trip:
        raise HTTPException(status_code=404, detail="No active trip")
    return trip

@app.patch("/drivers/me/trips/active/end", response_model=schemas.Trip)
def end_active_trip(db: Session = Depends(get_db), user_id: str = Depends(get_current_user_id)):
    trip = crud.get_active_trip_for_driver(db, user_id)
    if not trip:
        raise HTTPException(status_code=404, detail="No active trip to end")
    
    trip = crud.stop_trip(db, str(trip.id))
    return trip

@app.post("/drivers/me/trips/active/tap", response_model=schemas.TripDetail)
def tap_nfc_in_active_trip(
    body: dict, 
    db: Session = Depends(get_db), 
    user_id: str = Depends(get_current_user_id),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    trip = crud.get_active_trip_for_driver(db, user_id)
    if not trip:
        raise HTTPException(status_code=404, detail="No active trip")
    
    nfc_id = body.get("nfc_id")
    if not nfc_id:
        raise HTTPException(status_code=400, detail="nfc_id is required")
    
    # Run auto-expire in background
    background_tasks.add_task(auto_expire_task, db)
    
    try:
        detail = schemas.TripDetailCreate(trip_id=trip.id, nfc_id=nfc_id)
        return crud.add_trip_detail(db, detail)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# ---------------- Old endpoints ----------------
@app.post("/trips", response_model=schemas.Trip)
def create_trip(trip: schemas.TripCreate, db: Session = Depends(get_db)):
    return crud.create_trip(db, trip)

@app.patch("/trips/{trip_id}/start", response_model=schemas.Trip)
def start_trip(trip_id: str, db: Session = Depends(get_db)):
    trip = crud.start_trip(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip

@app.patch("/trips/{trip_id}/stop", response_model=schemas.Trip)
def stop_trip(trip_id: str, db: Session = Depends(get_db)):
    trip = crud.stop_trip(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip

@app.get("/trips/{trip_id}/details", response_model=list[schemas.TripDetail])
def get_trip_details(trip_id: str, db: Session = Depends(get_db)):
    return crud.get_trip_details(db, trip_id)

@app.post("/trip-details", response_model=schemas.TripDetail)
def add_trip_detail(trip_detail: schemas.TripDetailCreate, db: Session = Depends(get_db)):
    try:
        return crud.add_trip_detail(db, trip_detail)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# ---------------- Authentication ----------------
@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.Student).filter(models.Student.email == form_data.username).first()
    actual_role = "student"
    
    if not user:
        user = db.query(models.BusDriver).filter(models.BusDriver.email == form_data.username).first()
        actual_role = "driver"

    if not user:
        user = crud.get_admin_by_email(db, form_data.username)
        actual_role = "admin"
    
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": str(user.id), "role": actual_role})
    
    return {"access_token": access_token, "token_type": "bearer", "role": actual_role}

@app.get("/")
def root():
    return {"message": "NFC Bus System API"}
