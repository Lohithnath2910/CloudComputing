from sqlalchemy.orm import Session
import models
from schemas import StudentCreate, BusDriverCreate, TripCreate, TripDetailCreate, AdminCreate, BusCreate
from datetime import datetime, timedelta
from config import BASE_FARE, TAP_NOTIFICATION_EXPIRY_DURATION
from auth import get_password_hash, verify_password
import fcm_service

# ------------------- Students -------------------
def create_student(db: Session, student: StudentCreate):
    db_student = models.Student(
        name=student.name,
        email=student.email,
        password_hash=get_password_hash(student.password)
    )
    db.add(db_student)
    db.commit()
    db.refresh(db_student)
    return db_student

def get_student_by_id(db: Session, student_id: str):
    return db.query(models.Student).filter(models.Student.id == student_id).first()

def get_student_by_nfc(db: Session, nfc_id: str):
    return db.query(models.Student).filter(models.Student.nfc_id == nfc_id).first()

def delete_student(db: Session, student_id):
    student = db.query(models.Student).filter(models.Student.id == student_id).first()
    if student:
        db.delete(student)
        db.commit()
    return student

def update_student_nfc(db: Session, student_id, nfc_id: str):
    student = get_student_by_id(db, student_id)
    if not student:
        return None
    
    if nfc_id is None:
        student.is_nfc_blocked = True
        db.commit()
        db.refresh(student)
        return student
    
    if not nfc_id or not nfc_id.strip():
        raise ValueError("Invalid NFC ID")
    
    # ✅ FIXED: Allow re-registering same NFC (for unblocking)
    # If it's the same NFC ID, just unblock it
    if student.nfc_id == nfc_id:
        if student.is_nfc_blocked:
            # Unblock the same card
            student.is_nfc_blocked = False
            db.commit()
            db.refresh(student)
            return student
        else:
            # Card is already active, no need to do anything
            raise ValueError("NFC already registered and active on this account")
    
    # Check if the NEW nfc_id is registered to another student
    existing = db.query(models.Student).filter(models.Student.nfc_id == nfc_id).first()
    if existing and existing.id != student.id:
        raise ValueError("NFC already registered to another account")
    
    # Register the new NFC card
    student.nfc_id = nfc_id
    student.is_nfc_blocked = False
    db.commit()
    db.refresh(student)
    return student


def block_student_nfc(db: Session, student_id):
    student = db.query(models.Student).filter(models.Student.id == student_id).first()
    if student:
        student.is_nfc_blocked = True
        db.commit()
        db.refresh(student)
    return student

def update_fcm_token(db: Session, user_id: str, fcm_token: str, is_driver: bool = False):
    if is_driver:
        user = db.query(models.BusDriver).filter(models.BusDriver.id == user_id).first()
    else:
        user = db.query(models.Student).filter(models.Student.id == user_id).first()
    
    if user:
        user.fcm_token = fcm_token
        db.commit()
        db.refresh(user)
    return user

def get_student_trips(db: Session, student_id):
    student = db.query(models.Student).filter(models.Student.id == student_id).first()
    if not student or not student.nfc_id:
        return []
    
    trip_details = db.query(models.TripDetail).filter(models.TripDetail.nfc_id == student.nfc_id).all()
    trip_ids = [td.trip_id for td in trip_details]
    
    if not trip_ids:
        return []
    
    trips = db.query(models.Trip).filter(models.Trip.id.in_(trip_ids)).order_by(models.Trip.created_at.desc()).all()
    return trips

def get_pending_notifications_for_student(db: Session, student_id: str):
    """Get all pending/expired notifications for a student"""
    return db.query(models.PendingTapNotification).filter(
        models.PendingTapNotification.student_id == student_id,
        models.PendingTapNotification.status.in_(["pending", "expired"])
    ).order_by(models.PendingTapNotification.created_at.desc()).all()


# ------------------- Admin -------------------
def create_admin(db: Session, admin: AdminCreate):
    db_admin = models.Admin(
        name=admin.name,
        email=admin.email,
        password_hash=get_password_hash(admin.password),
    )
    db.add(db_admin)
    db.commit()
    db.refresh(db_admin)
    return db_admin


def get_admin_by_email(db: Session, email: str):
    return db.query(models.Admin).filter(models.Admin.email == email).first()


def get_admin_by_id(db: Session, admin_id: str):
    return db.query(models.Admin).filter(models.Admin.id == admin_id).first()


# ------------------- Buses -------------------
def create_bus(db: Session, bus: BusCreate):
    db_bus = models.Bus(
        bus_number=bus.bus_number,
        route_name=bus.route_name,
        capacity=bus.capacity,
    )
    db.add(db_bus)
    db.commit()
    db.refresh(db_bus)
    return db_bus


def get_bus_by_id(db: Session, bus_id: str):
    return db.query(models.Bus).filter(models.Bus.id == bus_id).first()


def list_buses(db: Session):
    return db.query(models.Bus).order_by(models.Bus.bus_number.asc()).all()

# ------------------- Bus Drivers -------------------
def create_driver(db: Session, driver: BusDriverCreate):
    db_driver = models.BusDriver(
        name=driver.name,
        email=driver.email,
        password_hash=get_password_hash(driver.password)
    )
    db.add(db_driver)
    db.commit()
    db.refresh(db_driver)
    return db_driver

def get_driver_by_id(db: Session, driver_id: str):
    return db.query(models.BusDriver).filter(models.BusDriver.id == driver_id).first()

def delete_driver(db: Session, driver_id):
    driver = db.query(models.BusDriver).filter(models.BusDriver.id == driver_id).first()
    if driver:
        db.delete(driver)
        db.commit()
    return driver

# ------------------- Trips -------------------
def create_trip(db: Session, trip: TripCreate):
    db_trip = models.Trip(
        driver_id=trip.driver_id,
        bus_id=trip.bus_id,
        name=trip.name,
        total_students=0,
        total_revenue=0.0
    )
    db.add(db_trip)
    db.commit()
    db.refresh(db_trip)
    return db_trip

def get_trip_by_id(db: Session, trip_id: str):
    return db.query(models.Trip).filter(models.Trip.id == trip_id).first()

def start_trip(db: Session, trip_id):
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if trip:
        trip.start_time = datetime.utcnow()
        db.commit()
        db.refresh(trip)
    return trip

def stop_trip(db: Session, trip_id):
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if trip:
        trip.end_time = datetime.utcnow()
        db.commit()
        db.refresh(trip)
    return trip

def get_driver_trips(db: Session, driver_id):
    return db.query(models.Trip).filter(models.Trip.driver_id == driver_id).order_by(models.Trip.created_at.desc()).all()

def get_trip_details(db: Session, trip_id):
    return db.query(models.TripDetail).filter(models.TripDetail.trip_id == trip_id).all()

def get_active_trip_for_driver(db: Session, driver_id: str):
    return db.query(models.Trip).filter(
        models.Trip.driver_id == driver_id,
        models.Trip.start_time.isnot(None),
        models.Trip.end_time.is_(None)
    ).first()

def get_trip_details_with_students(db: Session, trip_id: str):
    trip_details = (
        db.query(
            models.TripDetail.id,
            models.TripDetail.trip_id,
            models.TripDetail.nfc_id,
            models.TripDetail.timestamp,
            models.TripDetail.status,
            models.Student.name.label("student_name")
        )
        .outerjoin(models.Student, models.TripDetail.nfc_id == models.Student.nfc_id)
        .filter(models.TripDetail.trip_id == trip_id)
        .order_by(models.TripDetail.timestamp.asc())
        .all()
    )
    
    result = []
    for detail in trip_details:
        result.append({
            "id": str(detail.id),
            "trip_id": str(detail.trip_id),
            "nfc_id": detail.nfc_id,
            "timestamp": detail.timestamp.isoformat() if detail.timestamp else None,
            "student_name": detail.student_name or "Unknown Student",
            "status": detail.status
        })
    return result

# ------------------- Trip Details with Notification Flow -------------------
def add_trip_detail_with_notification(db: Session, trip_detail: TripDetailCreate):
    student = db.query(models.Student).filter(models.Student.nfc_id == trip_detail.nfc_id).first()
    
    if student and student.is_nfc_blocked:
        if student.fcm_token:
            fcm_service.send_blocked_nfc_alert(student.fcm_token)
        raise ValueError("This NFC ID is blocked")
    
    if not student:
        raise ValueError("Invalid NFC ID - not registered")
    
    existing = db.query(models.TripDetail).filter(
        models.TripDetail.trip_id == trip_detail.trip_id,
        models.TripDetail.nfc_id == trip_detail.nfc_id
    ).first()
    
    if existing:
        raise ValueError("Student already tapped for this trip")
    
    db_trip_detail = models.TripDetail(
        trip_id=trip_detail.trip_id,
        nfc_id=trip_detail.nfc_id,
        fare_paid=BASE_FARE,
        status="pending"
    )
    db.add(db_trip_detail)
    db.commit()
    db.refresh(db_trip_detail)
    
    pending_notification = models.PendingTapNotification(
        trip_detail_id=db_trip_detail.id,
        nfc_id=trip_detail.nfc_id,
        student_id=student.id,
        trip_id=trip_detail.trip_id,
        expires_at=datetime.utcnow() + timedelta(seconds=TAP_NOTIFICATION_EXPIRY_DURATION)
    )
    db.add(pending_notification)
    db.commit()
    db.refresh(pending_notification)
    
    if student.fcm_token:
        fcm_service.send_tap_notification(
            fcm_token=student.fcm_token,
            nfc_id=trip_detail.nfc_id,
            notification_id=str(pending_notification.id),
            student_name=student.name
        )
    
    return db_trip_detail

def respond_to_tap_notification(db: Session, notification_id: str, accepted: bool, student_id: str):
    notification = db.query(models.PendingTapNotification).filter(
        models.PendingTapNotification.id == notification_id,
        models.PendingTapNotification.student_id == student_id
    ).first()
    
    if not notification:
        raise ValueError("Notification not found or unauthorized")
    
    if notification.status != "pending":
        raise ValueError("Notification already processed")
    
    trip_detail = db.query(models.TripDetail).filter(
        models.TripDetail.id == notification.trip_detail_id
    ).first()
    
    if not trip_detail:
        raise ValueError("Trip detail not found")
    
    # Check if expired
    if datetime.utcnow() > notification.expires_at:
        # Auto-accept if expired
        trip_detail.status = "expired_accepted"
        notification.status = "expired"
        
        # Send expired warning to student
        student = db.query(models.Student).filter(models.Student.id == student_id).first()
        if student and student.fcm_token:
            fcm_service.send_expired_notification_alert(student.fcm_token, notification.nfc_id)
    else:
        if accepted:
            trip_detail.status = "accepted"
            notification.status = "accepted"
        else:
            trip_detail.status = "denied_misused"
            notification.status = "denied"
    
    # Update trip totals
    trip = db.query(models.Trip).filter(models.Trip.id == notification.trip_id).first()
    if trip:
        trip.total_students += 1
        trip.total_revenue += BASE_FARE
    
    db.commit()
    db.refresh(trip_detail)
    
    return trip_detail

def auto_expire_old_notifications(db: Session):
    """Background task to auto-expire old notifications"""
    expired_notifications = db.query(models.PendingTapNotification).filter(
        models.PendingTapNotification.status == "pending",
        models.PendingTapNotification.expires_at < datetime.utcnow()
    ).all()
    
    for notification in expired_notifications:
        trip_detail = db.query(models.TripDetail).filter(
            models.TripDetail.id == notification.trip_detail_id
        ).first()
        
        if trip_detail:
            trip_detail.status = "expired_accepted"
            
            # Update trip totals
            trip = db.query(models.Trip).filter(models.Trip.id == notification.trip_id).first()
            if trip:
                trip.total_students += 1
                trip.total_revenue += BASE_FARE
            
            # Send warning to student
            student = db.query(models.Student).filter(models.Student.id == notification.student_id).first()
            if student and student.fcm_token:
                fcm_service.send_expired_notification_alert(student.fcm_token, notification.nfc_id)
        
        notification.status = "expired"
    
    db.commit()
    return len(expired_notifications)

def add_trip_detail(db: Session, trip_detail: TripDetailCreate):
    return add_trip_detail_with_notification(db, trip_detail)

def dismiss_expired_warning(db: Session, notification_id: str, student_id: str):
    """Student dismisses the expired warning - marks it as reviewed"""
    notification = db.query(models.PendingTapNotification).filter(
        models.PendingTapNotification.id == notification_id,
        models.PendingTapNotification.student_id == student_id
    ).first()
    
    if notification and notification.status == "expired":
        notification.status = "reviewed"
        db.commit()
    
    return notification
