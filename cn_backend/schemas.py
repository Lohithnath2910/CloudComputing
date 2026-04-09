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

class TripBase(BaseModel):
    driver_id: UUID
    name: Optional[str] = "Trip"

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
