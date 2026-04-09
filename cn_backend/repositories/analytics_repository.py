from sqlalchemy import func
from sqlalchemy.orm import Session

import models


def get_dashboard_totals(db: Session):
    total_students = db.query(func.count(models.Student.id)).scalar() or 0
    total_drivers = db.query(func.count(models.BusDriver.id)).scalar() or 0
    total_buses = db.query(func.count(models.Bus.id)).scalar() or 0
    total_trips = db.query(func.count(models.Trip.id)).scalar() or 0
    active_trips = (
        db.query(func.count(models.Trip.id))
        .filter(models.Trip.start_time.isnot(None), models.Trip.end_time.is_(None))
        .scalar()
        or 0
    )
    total_revenue = db.query(func.coalesce(func.sum(models.Trip.total_revenue), 0.0)).scalar() or 0.0

    return {
        "students": int(total_students),
        "drivers": int(total_drivers),
        "buses": int(total_buses),
        "trips": int(total_trips),
        "active_trips": int(active_trips),
        "revenue": float(total_revenue),
    }


def get_revenue_time_series(db: Session):
    rows = (
        db.query(
            func.date_trunc("day", models.Trip.created_at).label("bucket"),
            func.coalesce(func.sum(models.Trip.total_revenue), 0.0).label("value"),
        )
        .group_by("bucket")
        .order_by("bucket")
        .all()
    )
    return rows


def get_revenue_per_driver(db: Session):
    rows = (
        db.query(
            models.BusDriver.id,
            models.BusDriver.name,
            func.coalesce(func.sum(models.Trip.total_revenue), 0.0).label("revenue"),
        )
        .outerjoin(models.Trip, models.Trip.driver_id == models.BusDriver.id)
        .group_by(models.BusDriver.id, models.BusDriver.name)
        .order_by(func.coalesce(func.sum(models.Trip.total_revenue), 0.0).desc())
        .all()
    )
    return rows


def get_revenue_per_bus(db: Session):
    rows = (
        db.query(
            models.Bus.id,
            models.Bus.bus_number,
            func.coalesce(func.sum(models.Trip.total_revenue), 0.0).label("revenue"),
        )
        .outerjoin(models.Trip, models.Trip.bus_id == models.Bus.id)
        .group_by(models.Bus.id, models.Bus.bus_number)
        .order_by(func.coalesce(func.sum(models.Trip.total_revenue), 0.0).desc())
        .all()
    )
    return rows


def get_peak_hours(db: Session):
    rows = (
        db.query(
            func.extract("hour", models.TripDetail.timestamp).label("hour"),
            func.count(models.TripDetail.id).label("taps"),
        )
        .group_by("hour")
        .order_by("hour")
        .all()
    )
    return rows


def get_driver_performance(db: Session):
    rows = (
        db.query(
            models.BusDriver.id,
            models.BusDriver.name,
            func.count(models.Trip.id).label("trip_count"),
            func.coalesce(func.sum(models.Trip.total_students), 0).label("students"),
            func.coalesce(func.sum(models.Trip.total_revenue), 0.0).label("revenue"),
        )
        .outerjoin(models.Trip, models.Trip.driver_id == models.BusDriver.id)
        .group_by(models.BusDriver.id, models.BusDriver.name)
        .order_by(func.coalesce(func.sum(models.Trip.total_revenue), 0.0).desc())
        .all()
    )
    return rows


def get_student_usage_stats(db: Session):
    rows = (
        db.query(
            models.Student.id,
            models.Student.name,
            func.count(models.TripDetail.id).label("rides"),
            func.coalesce(func.sum(models.TripDetail.fare_paid), 0.0).label("fare_total"),
        )
        .outerjoin(models.TripDetail, models.TripDetail.nfc_id == models.Student.nfc_id)
        .group_by(models.Student.id, models.Student.name)
        .order_by(func.count(models.TripDetail.id).desc())
        .all()
    )
    return rows


def get_trip_status_distribution(db: Session):
    rows = (
        db.query(models.TripDetail.status, func.count(models.TripDetail.id).label("count"))
        .group_by(models.TripDetail.status)
        .order_by(func.count(models.TripDetail.id).desc())
        .all()
    )
    return rows
