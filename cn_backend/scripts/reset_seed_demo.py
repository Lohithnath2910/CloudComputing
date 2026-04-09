from datetime import datetime, timedelta
import random
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from database import SessionLocal
import models
from auth import get_password_hash


def clear_all(db):
    db.query(models.PendingTapNotification).delete(synchronize_session=False)
    db.query(models.TripDetail).delete(synchronize_session=False)
    db.query(models.Trip).delete(synchronize_session=False)
    db.query(models.DriverBusAssignment).delete(synchronize_session=False)
    db.query(models.Student).delete(synchronize_session=False)
    db.query(models.BusDriver).delete(synchronize_session=False)
    db.query(models.Bus).delete(synchronize_session=False)
    db.query(models.Admin).delete(synchronize_session=False)
    db.commit()


def seed(db):
    random.seed(42)
    password_hash = get_password_hash("TestPass123!")

    admin = models.Admin(
        name="Admin 1",
        email="admin1@example.com",
        password_hash=password_hash,
        is_active=True,
    )
    db.add(admin)

    buses = []
    for idx, route in enumerate(["Route A", "Route B", "Route C", "Route D"], start=1):
        bus = models.Bus(
            bus_number=f"BUS-10{idx}",
            route_name=route,
            capacity=48,
            is_active=True,
        )
        buses.append(bus)
        db.add(bus)

    drivers = []
    for i in range(1, 5):
        driver = models.BusDriver(
            name=f"Driver {i}",
            email=f"driver{i}@test.com",
            password_hash=password_hash,
        )
        drivers.append(driver)
        db.add(driver)

    students = []
    for i in range(1, 21):
        student = models.Student(
            name=f"Student {i}",
            email=f"student{i}@test.com",
            nfc_id=f"NFC-{i:03d}",
            password_hash=password_hash,
            is_nfc_blocked=False,
        )
        students.append(student)
        db.add(student)

    db.commit()
    db.refresh(admin)
    for bus in buses:
        db.refresh(bus)
    for driver in drivers:
        db.refresh(driver)
    for student in students:
        db.refresh(student)

    today = datetime.now().replace(minute=0, second=0, microsecond=0)
    day_start = today.replace(hour=7)

    for i, driver in enumerate(drivers):
        assignment = models.DriverBusAssignment(
            driver_id=driver.id,
            bus_id=buses[i].id,
            start_time=day_start,
            end_time=day_start.replace(hour=19, minute=30),
            assigned_by_admin_id=admin.id,
            notes="Seeded assignment",
        )
        db.add(assignment)

    db.commit()

    start_hours = [8, 10, 12, 14, 16, 18]
    statuses = [
        "accepted",
        "accepted",
        "accepted",
        "expired_accepted",
        "denied_misused",
    ]

    total_trips = 0
    total_taps = 0
    for i, bus in enumerate(buses):
        driver = drivers[i]
        for hour in start_hours:
            start = today.replace(hour=hour, minute=random.choice([0, 10, 20, 30]))
            end = start + timedelta(minutes=random.choice([70, 80, 90]))
            trip = models.Trip(
                driver_id=driver.id,
                bus_id=bus.id,
                name=f"{bus.route_name} {start.strftime('%H:%M')}",
                start_time=start,
                end_time=end,
                created_at=start - timedelta(minutes=8),
                total_students=0,
                total_revenue=0.0,
            )
            db.add(trip)
            db.commit()
            db.refresh(trip)
            total_trips += 1

            tapped = random.sample(students, random.randint(5, 10))
            revenue = 0.0
            for s in tapped:
                status = random.choice(statuses)
                tap_time = start + timedelta(minutes=random.randint(2, 65))
                detail = models.TripDetail(
                    trip_id=trip.id,
                    nfc_id=s.nfc_id,
                    fare_paid=20.0,
                    timestamp=tap_time,
                    created_at=tap_time,
                    status=status,
                )
                db.add(detail)
                total_taps += 1
                if status in ("accepted", "expired_accepted"):
                    revenue += 20.0

            trip.total_students = len(tapped)
            trip.total_revenue = revenue
            db.commit()

    print("RESET_AND_SEED_DONE")
    print("ADMIN_LOGIN=admin1@example.com / TestPass123!")
    print("DRIVER_LOGIN_EXAMPLE=driver1@test.com / TestPass123!")
    print("STUDENT_LOGIN_EXAMPLE=student1@test.com / TestPass123!")
    print("TOTAL_BUSES=4")
    print("TOTAL_DRIVERS=4")
    print("TOTAL_STUDENTS=20")
    print(f"TOTAL_TRIPS={total_trips}")
    print(f"TOTAL_TAPS={total_taps}")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        clear_all(db)
        seed(db)
    finally:
        db.close()
