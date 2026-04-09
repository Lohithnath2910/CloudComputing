"""Generate long-timespan demo trip/payment activity for analytics.

This script appends synthetic historical activity and does not delete data.

Examples:
  python scripts/simulate_live_payments.py
  python scripts/simulate_live_payments.py --days 180 --seed 42 --students 80
"""

from __future__ import annotations

import argparse
import os
import random
import sys
from datetime import datetime, timedelta
from typing import List

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from sqlalchemy.orm import Session

import models
from auth import get_password_hash
from database import SessionLocal


STATUS_WEIGHTS = [
    ("accepted", 0.68),
    ("expired_accepted", 0.16),
    ("denied_misused", 0.10),
    ("pending", 0.06),
]


def choose_status(rng: random.Random) -> str:
    bucket = rng.random()
    cumulative = 0.0
    for status, weight in STATUS_WEIGHTS:
        cumulative += weight
        if bucket <= cumulative:
            return status
    return "accepted"


def ensure_admin(db: Session, password_hash: str) -> models.Admin:
    admin = db.query(models.Admin).filter(models.Admin.email == "admin1@example.com").first()
    if admin:
        return admin
    admin = models.Admin(
        name="Admin 1",
        email="admin1@example.com",
        password_hash=password_hash,
        is_active=True,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


def ensure_buses(db: Session, target: int) -> List[models.Bus]:
    buses = db.query(models.Bus).order_by(models.Bus.created_at.asc()).all()
    next_idx = 1
    while len(buses) < target:
        bus_number = f"DEMO-BUS-{100 + next_idx}"
        exists = db.query(models.Bus).filter(models.Bus.bus_number == bus_number).first()
        next_idx += 1
        if exists:
            continue
        bus = models.Bus(
            bus_number=bus_number,
            route_name=f"Demo Route {len(buses) + 1}",
            capacity=48,
            is_active=True,
        )
        db.add(bus)
        db.flush()
        buses.append(bus)
    db.commit()
    return db.query(models.Bus).order_by(models.Bus.created_at.asc()).all()[:target]


def ensure_drivers(db: Session, target: int, password_hash: str) -> List[models.BusDriver]:
    drivers = db.query(models.BusDriver).order_by(models.BusDriver.created_at.asc()).all()
    next_idx = 1
    while len(drivers) < target:
        email = f"demo_driver{next_idx}@test.com"
        exists = db.query(models.BusDriver).filter(models.BusDriver.email == email).first()
        next_idx += 1
        if exists:
            continue
        driver = models.BusDriver(
            name=f"Demo Driver {len(drivers) + 1}",
            email=email,
            password_hash=password_hash,
        )
        db.add(driver)
        db.flush()
        drivers.append(driver)
    db.commit()
    return db.query(models.BusDriver).order_by(models.BusDriver.created_at.asc()).all()[:target]


def ensure_students(db: Session, target: int, password_hash: str) -> List[models.Student]:
    students = db.query(models.Student).order_by(models.Student.created_at.asc()).all()
    next_idx = 1
    while len(students) < target:
        email = f"demo_student{next_idx}@test.com"
        nfc_id = f"DEMO-NFC-{next_idx:04d}"
        exists_email = db.query(models.Student).filter(models.Student.email == email).first()
        exists_nfc = db.query(models.Student).filter(models.Student.nfc_id == nfc_id).first()
        next_idx += 1
        if exists_email or exists_nfc:
            continue
        student = models.Student(
            name=f"Demo Student {len(students) + 1}",
            email=email,
            nfc_id=nfc_id,
            password_hash=password_hash,
            is_nfc_blocked=False,
        )
        db.add(student)
        db.flush()
        students.append(student)
    db.commit()
    return db.query(models.Student).order_by(models.Student.created_at.asc()).all()[:target]


def ensure_assignments(
    db: Session,
    admin: models.Admin,
    buses: List[models.Bus],
    drivers: List[models.BusDriver],
    start_at: datetime,
    end_at: datetime,
) -> None:
    for idx, driver in enumerate(drivers):
        bus = buses[idx % len(buses)]
        existing = (
            db.query(models.DriverBusAssignment)
            .filter(models.DriverBusAssignment.driver_id == driver.id)
            .filter(models.DriverBusAssignment.bus_id == bus.id)
            .filter(models.DriverBusAssignment.start_time <= end_at)
            .filter(
                (models.DriverBusAssignment.end_time.is_(None))
                | (models.DriverBusAssignment.end_time >= start_at)
            )
            .first()
        )
        if existing:
            continue
        db.add(
            models.DriverBusAssignment(
                driver_id=driver.id,
                bus_id=bus.id,
                start_time=start_at,
                end_time=end_at,
                assigned_by_admin_id=admin.id,
                notes="Auto-generated for simulation",
            )
        )
    db.commit()


def simulate_activity(
    db: Session,
    buses: List[models.Bus],
    drivers: List[models.BusDriver],
    students: List[models.Student],
    days: int,
    min_trips_per_day: int,
    max_trips_per_day: int,
    seed: int,
) -> tuple[int, int, float]:
    rng = random.Random(seed)
    now = datetime.now().replace(minute=0, second=0, microsecond=0)
    start_day = (now - timedelta(days=days)).replace(hour=0)
    base_hours = [6, 8, 10, 12, 14, 16, 18, 20]
    fare_options = [15.0, 20.0, 25.0]

    trips_created = 0
    taps_created = 0
    revenue_created = 0.0

    for day_index in range(days):
        day = start_day + timedelta(days=day_index)
        weekend_factor = 0.7 if day.weekday() >= 5 else 1.0

        for idx, bus in enumerate(buses):
            driver = drivers[idx % len(drivers)]
            trip_count = max(
                1,
                int(round(rng.randint(min_trips_per_day, max_trips_per_day) * weekend_factor)),
            )

            for trip_no in range(trip_count):
                hour = base_hours[(trip_no + idx + day_index) % len(base_hours)]
                minute = rng.choice([0, 5, 10, 15, 20, 25, 30, 35, 40])
                start = day.replace(hour=hour, minute=minute)
                duration_minutes = rng.randint(55, 100)
                end = start + timedelta(minutes=duration_minutes)

                trip = models.Trip(
                    driver_id=driver.id,
                    bus_id=bus.id,
                    name=f"{bus.route_name or bus.bus_number} {start.strftime('%Y-%m-%d %H:%M')}",
                    start_time=start,
                    end_time=end,
                    created_at=start - timedelta(minutes=5),
                    total_students=0,
                    total_revenue=0.0,
                )
                db.add(trip)
                db.flush()

                if len(students) < 5:
                    selected_students = students
                else:
                    tap_count = rng.randint(6, min(26, len(students)))
                    selected_students = rng.sample(students, tap_count)

                trip_revenue = 0.0
                for student in selected_students:
                    status = choose_status(rng)
                    fare = float(rng.choice(fare_options))
                    tap_time = start + timedelta(minutes=rng.randint(1, max(2, duration_minutes - 2)))
                    detail = models.TripDetail(
                        trip_id=trip.id,
                        nfc_id=student.nfc_id,
                        fare_paid=fare,
                        timestamp=tap_time,
                        created_at=tap_time,
                        status=status,
                    )
                    db.add(detail)
                    taps_created += 1
                    if status in ("accepted", "expired_accepted"):
                        trip_revenue += fare

                trip.total_students = len(selected_students)
                trip.total_revenue = round(trip_revenue, 2)
                revenue_created += trip.total_revenue
                trips_created += 1

        db.commit()
        if (day_index + 1) % 15 == 0 or day_index + 1 == days:
            print(
                f"PROGRESS day={day_index + 1}/{days} trips={trips_created} taps={taps_created} revenue={round(revenue_created, 2)}"
            )

    return trips_created, taps_created, round(revenue_created, 2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simulate long-range live payments for analytics demos.")
    parser.add_argument("--days", type=int, default=100, help="Number of historical days to generate.")
    parser.add_argument("--seed", type=int, default=20260409, help="Random seed for reproducible output.")
    parser.add_argument("--buses", type=int, default=4, help="Minimum buses required for simulation.")
    parser.add_argument("--drivers", type=int, default=4, help="Minimum drivers required for simulation.")
    parser.add_argument("--students", type=int, default=80, help="Minimum students required for simulation.")
    parser.add_argument(
        "--min-trips-per-day",
        type=int,
        default=2,
        help="Minimum trips per bus per day.",
    )
    parser.add_argument(
        "--max-trips-per-day",
        type=int,
        default=4,
        help="Maximum trips per bus per day.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.days <= 0:
        raise ValueError("--days must be greater than 0")
    if args.min_trips_per_day <= 0:
        raise ValueError("--min-trips-per-day must be greater than 0")
    if args.max_trips_per_day < args.min_trips_per_day:
        raise ValueError("--max-trips-per-day must be >= --min-trips-per-day")

    db = SessionLocal()
    try:
        password_hash = get_password_hash("TestPass123!")
        admin = ensure_admin(db, password_hash)
        buses = ensure_buses(db, args.buses)
        drivers = ensure_drivers(db, args.drivers, password_hash)
        students = ensure_students(db, args.students, password_hash)

        now = datetime.now().replace(minute=0, second=0, microsecond=0)
        assignment_start = now - timedelta(days=args.days + 3)
        assignment_end = now + timedelta(days=30)
        ensure_assignments(db, admin, buses, drivers, assignment_start, assignment_end)

        trips, taps, revenue = simulate_activity(
            db=db,
            buses=buses,
            drivers=drivers,
            students=students,
            days=args.days,
            min_trips_per_day=args.min_trips_per_day,
            max_trips_per_day=args.max_trips_per_day,
            seed=args.seed,
        )

        print("SIMULATION_DONE")
        print("ADMIN_LOGIN=admin1@example.com / TestPass123!")
        print(f"TOTAL_BUSES={len(buses)}")
        print(f"TOTAL_DRIVERS={len(drivers)}")
        print(f"TOTAL_STUDENTS={len(students)}")
        print(f"TRIPS_CREATED={trips}")
        print(f"TAPS_CREATED={taps}")
        print(f"REVENUE_CREATED={revenue}")
        print(f"DAYS_SPANNED={args.days}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
