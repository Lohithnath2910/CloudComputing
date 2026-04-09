from sqlalchemy import Column, String, Integer, Float, ForeignKey, DateTime, Boolean, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from database import Base


class Admin(Base):
    __tablename__ = "admins"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Bus(Base):
    __tablename__ = "buses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    bus_number = Column(String, unique=True, nullable=False)
    route_name = Column(String, nullable=True)
    capacity = Column(Integer, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    trips = relationship("Trip", back_populates="bus")

class Student(Base):
    __tablename__ = "students"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    email = Column(String, nullable=True)
    nfc_id = Column(String, unique=True, nullable=True)
    is_nfc_blocked = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    password_hash = Column(String, nullable=False)
    fcm_token = Column(String, nullable=True)
    
    trip_details = relationship("TripDetail", back_populates="student", 
                           primaryjoin="Student.nfc_id == foreign(TripDetail.nfc_id)")

class BusDriver(Base):
    __tablename__ = "bus_drivers"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    email = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    password_hash = Column(String, nullable=False)
    fcm_token = Column(String, nullable=True)
    
    trips = relationship("Trip", back_populates="driver")

class Trip(Base):
    __tablename__ = "trips"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    driver_id = Column(UUID(as_uuid=True), ForeignKey("bus_drivers.id"), nullable=False)
    bus_id = Column(UUID(as_uuid=True), ForeignKey("buses.id"), nullable=True)
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    total_students = Column(Integer, default=0)
    total_revenue = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    name = Column(String, default="Trip")
    
    driver = relationship("BusDriver", back_populates="trips")
    bus = relationship("Bus", back_populates="trips")
    trip_details = relationship("TripDetail", back_populates="trip")

    __table_args__ = (
        Index("ix_trips_driver_id", "driver_id"),
        Index("ix_trips_created_at", "created_at"),
        Index("ix_trips_bus_id", "bus_id"),
    )

class TripDetail(Base):
    __tablename__ = "trip_details"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trip_id = Column(UUID(as_uuid=True), ForeignKey("trips.id"), nullable=False)
    nfc_id = Column(String, nullable=False)
    fare_paid = Column(Float, default=20.0)
    timestamp = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String, default="pending")  # pending, accepted, denied_misused, expired_accepted
    
    trip = relationship("Trip", back_populates="trip_details")
    student = relationship("Student", back_populates="trip_details",
                      primaryjoin="TripDetail.nfc_id == Student.nfc_id",
                      foreign_keys="[TripDetail.nfc_id]")

    __table_args__ = (
        Index("ix_trip_details_trip_id", "trip_id"),
        Index("ix_trip_details_timestamp", "timestamp"),
        Index("ix_trip_details_nfc_id", "nfc_id"),
    )

class PendingTapNotification(Base):
    __tablename__ = "pending_tap_notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trip_detail_id = Column(UUID(as_uuid=True), ForeignKey("trip_details.id"), nullable=False)
    nfc_id = Column(String, nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=True)
    trip_id = Column(UUID(as_uuid=True), ForeignKey("trips.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    status = Column(String, default="pending")  # pending, accepted, denied, expired

    __table_args__ = (
        Index("ix_pending_tap_notifications_trip_id", "trip_id"),
        Index("ix_pending_tap_notifications_status", "status"),
        Index("ix_pending_tap_notifications_expires_at", "expires_at"),
    )
