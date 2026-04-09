from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class StudentBase(BaseModel):
    name: str
    email: Optional[str] = None
    nfc_id: Optional[str] = None

class StudentCreate(StudentBase):
    password: str

class Student(StudentBase):
    id: UUID
    created_at: datetime
    is_nfc_blocked: bool = False
    fcm_token: Optional[str] = None
    
    class Config:
        from_attributes = True

class BusDriverBase(BaseModel):
    name: str
    email: Optional[str] = None

class BusDriverCreate(BusDriverBase):
    password: str

class BusDriver(BusDriverBase):
    id: UUID
    created_at: datetime
    fcm_token: Optional[str] = None
    
    class Config:
        from_attributes = True


class AdminBase(BaseModel):
    name: str
    email: str


class AdminCreate(AdminBase):
    password: str


class Admin(AdminBase):
    id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class BusBase(BaseModel):
    bus_number: str
    route_name: Optional[str] = None
    capacity: Optional[int] = None


class BusCreate(BusBase):
    pass


class Bus(BusBase):
    id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class DriverBusAssignmentBase(BaseModel):
    driver_id: UUID
    bus_id: UUID
    start_time: datetime
    end_time: Optional[datetime] = None
    notes: Optional[str] = None


class DriverBusAssignmentCreate(DriverBusAssignmentBase):
    pass


class DriverBusAssignment(DriverBusAssignmentBase):
    id: UUID
    assigned_by_admin_id: Optional[UUID] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ActiveTripCreateRequest(BaseModel):
    name: Optional[str] = "Trip"
    bus_id: Optional[UUID] = None

class TripBase(BaseModel):
    driver_id: UUID
    name: Optional[str] = "Trip"
    bus_id: Optional[UUID] = None

class TripCreate(TripBase):
    pass

class Trip(TripBase):
    id: UUID
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    total_students: int
    total_revenue: float
    created_at: datetime
    
    class Config:
        from_attributes = True

class TripDetailBase(BaseModel):
    trip_id: UUID
    nfc_id: str

class TripDetailCreate(TripDetailBase):
    pass

class TripDetail(TripDetailBase):
    id: UUID
    timestamp: datetime
    status: str = "pending"
    
    class Config:
        from_attributes = True

class NfcUpdate(BaseModel):
    nfc_id: str

class TripNameUpdate(BaseModel):
    name: str

class FcmTokenUpdate(BaseModel):
    fcm_token: str

class TapNotificationResponse(BaseModel):
    notification_id: UUID
    accepted: bool

class BlockNfcRequest(BaseModel):
    should_block: bool

class PendingNotification(BaseModel):
    id: UUID
    nfc_id: str
    trip_id: UUID
    created_at: datetime
    expires_at: datetime
    status: str
    
    class Config:
        from_attributes = True


class StudentTripSummary(BaseModel):
    id: UUID
    driver_id: UUID
    bus_id: Optional[UUID] = None
    name: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    total_students: int
    total_revenue: float
    created_at: datetime
    bus_number: Optional[str] = None
    bus_route_name: Optional[str] = None
    driver_name: Optional[str] = None
    driver_email: Optional[str] = None


class StudentTripTapRecord(BaseModel):
    id: UUID
    timestamp: datetime
    status: str
    fare_paid: float


class StudentTripDetailView(BaseModel):
    trip: StudentTripSummary
    student_nfc_id: Optional[str] = None
    tap_count: int
    tap_records: List[StudentTripTapRecord]


class LabelValuePoint(BaseModel):
    label: str
    value: float


class TimeSeriesPoint(BaseModel):
    timestamp: str
    value: float


class DashboardSummary(BaseModel):
    totals: dict
    revenue_time_series: List[TimeSeriesPoint]
    top_drivers: List[LabelValuePoint]
    top_buses: List[LabelValuePoint]


class AnalyticsResponse(BaseModel):
    labels: List[str]
    values: List[float]
    datasets: Optional[List[dict]] = None
    points: Optional[List[dict]] = None


class AdminStudentTripAudit(BaseModel):
    trip_detail_id: UUID
    nfc_id: str
    timestamp: datetime
    status: str
    fare_paid: float
    student_id: Optional[UUID] = None
    student_name: Optional[str] = None
    student_email: Optional[str] = None
    trip_id: UUID
    trip_name: Optional[str] = None
    trip_start_time: Optional[datetime] = None
    trip_end_time: Optional[datetime] = None
    bus_id: Optional[UUID] = None
    bus_number: Optional[str] = None
    route_name: Optional[str] = None
    driver_id: Optional[UUID] = None
    driver_name: Optional[str] = None
    driver_email: Optional[str] = None
