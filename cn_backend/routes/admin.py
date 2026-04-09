from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from jose import jwt
from sqlalchemy.orm import Session

import crud
import schemas
from auth import ALGORITHM, SECRET_KEY, create_access_token, oauth2_scheme, verify_password
from database import get_db
from services import analytics_service


router = APIRouter(prefix="/admin", tags=["admin"])


def get_current_admin_id(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        role = payload.get("role")
        if user_id is None or role != "admin":
            raise HTTPException(status_code=401, detail="Invalid admin token")
        return user_id
    except Exception:
        raise HTTPException(status_code=401, detail="Could not validate admin credentials")


@router.post("", response_model=schemas.Admin)
def create_admin(admin: schemas.AdminCreate, db: Session = Depends(get_db)):
    existing = crud.get_admin_by_email(db, admin.email)
    if existing:
        raise HTTPException(status_code=400, detail="Admin email already exists")
    return crud.create_admin(db, admin)


@router.post("/token")
def login_admin(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    admin = crud.get_admin_by_email(db, form_data.username)
    if not admin or not verify_password(form_data.password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(data={"sub": str(admin.id), "role": "admin"})
    return {"access_token": token, "token_type": "bearer", "role": "admin"}


@router.get("/buses", response_model=list[schemas.Bus])
def list_buses(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return crud.list_buses(db)


@router.post("/buses", response_model=schemas.Bus)
def create_bus(bus: schemas.BusCreate, db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return crud.create_bus(db, bus)


@router.get("/bus-assignments", response_model=list[schemas.DriverBusAssignment])
def list_bus_assignments(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return crud.list_assignments(db)


@router.post("/bus-assignments", response_model=schemas.DriverBusAssignment)
def create_bus_assignment(
    payload: schemas.DriverBusAssignmentCreate,
    db: Session = Depends(get_db),
    admin_id: str = Depends(get_current_admin_id),
):
    try:
        return crud.create_driver_bus_assignment(db, payload, admin_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/dashboard", response_model=schemas.DashboardSummary)
def dashboard(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return analytics_service.get_dashboard(db)


@router.get("/revenue")
def revenue(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return analytics_service.get_revenue(db)


@router.get("/peak-hours")
def peak_hours(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return analytics_service.get_peak_hours(db)


@router.get("/drivers/performance")
def driver_performance(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return analytics_service.get_driver_performance(db)


@router.get("/students/stats")
def student_stats(db: Session = Depends(get_db), _: str = Depends(get_current_admin_id)):
    return analytics_service.get_student_stats(db)
