from sqlalchemy.orm import Session

from repositories import analytics_repository


def _to_label_values(rows, label_key, value_key):
    labels = []
    values = []
    points = []

    for row in rows:
        label = str(getattr(row, label_key))
        value = float(getattr(row, value_key) or 0.0)
        labels.append(label)
        values.append(value)
        points.append({"label": label, "value": value})

    return {
        "labels": labels,
        "values": values,
        "points": points,
    }


def get_dashboard(db: Session):
    totals = analytics_repository.get_dashboard_totals(db)

    revenue_rows = analytics_repository.get_revenue_time_series(db)
    revenue_points = [
        {"timestamp": row.bucket.isoformat(), "value": float(row.value or 0.0)}
        for row in revenue_rows
        if row.bucket is not None
    ]

    top_driver_rows = analytics_repository.get_revenue_per_driver(db)[:5]
    top_bus_rows = analytics_repository.get_revenue_per_bus(db)[:5]

    return {
        "totals": totals,
        "revenue_time_series": revenue_points,
        "top_drivers": [
            {"label": row.name, "value": float(row.revenue or 0.0)} for row in top_driver_rows
        ],
        "top_buses": [
            {"label": row.bus_number, "value": float(row.revenue or 0.0)} for row in top_bus_rows
        ],
    }


def get_revenue(db: Session):
    per_driver = _to_label_values(analytics_repository.get_revenue_per_driver(db), "name", "revenue")
    per_bus = _to_label_values(analytics_repository.get_revenue_per_bus(db), "bus_number", "revenue")

    time_rows = analytics_repository.get_revenue_time_series(db)
    time_points = [
        {"timestamp": row.bucket.isoformat(), "value": float(row.value or 0.0)}
        for row in time_rows
        if row.bucket is not None
    ]

    return {
        "driver": per_driver,
        "bus": per_bus,
        "time_series": {
            "labels": [p["timestamp"] for p in time_points],
            "values": [p["value"] for p in time_points],
            "points": time_points,
        },
    }


def get_peak_hours(db: Session):
    rows = analytics_repository.get_peak_hours(db)

    labels = []
    values = []
    points = []
    for row in rows:
        hour = int(row.hour)
        label = f"{hour:02d}:00"
        value = int(row.taps or 0)
        labels.append(label)
        values.append(value)
        points.append({"label": label, "value": value})

    return {
        "labels": labels,
        "values": values,
        "points": points,
    }


def get_driver_performance(db: Session):
    rows = analytics_repository.get_driver_performance(db)

    labels = []
    revenue_values = []
    trip_values = []
    student_values = []

    for row in rows:
        labels.append(row.name)
        revenue_values.append(float(row.revenue or 0.0))
        trip_values.append(int(row.trip_count or 0))
        student_values.append(int(row.students or 0))

    return {
        "labels": labels,
        "datasets": [
            {"name": "revenue", "values": revenue_values},
            {"name": "trip_count", "values": trip_values},
            {"name": "students", "values": student_values},
        ],
        "points": [
            {
                "label": row.name,
                "revenue": float(row.revenue or 0.0),
                "trip_count": int(row.trip_count or 0),
                "students": int(row.students or 0),
            }
            for row in rows
        ],
    }


def get_student_stats(db: Session):
    usage_rows = analytics_repository.get_student_usage_stats(db)
    distribution_rows = analytics_repository.get_trip_status_distribution(db)

    usage_labels = [row.name for row in usage_rows]
    usage_rides = [int(row.rides or 0) for row in usage_rows]
    usage_fare = [float(row.fare_total or 0.0) for row in usage_rows]

    distribution_labels = [row.status for row in distribution_rows]
    distribution_values = [int(row.count or 0) for row in distribution_rows]

    return {
        "usage": {
            "labels": usage_labels,
            "datasets": [
                {"name": "rides", "values": usage_rides},
                {"name": "fare_total", "values": usage_fare},
            ],
            "points": [
                {"label": row.name, "rides": int(row.rides or 0), "fare_total": float(row.fare_total or 0.0)}
                for row in usage_rows
            ],
        },
        "status_distribution": {
            "labels": distribution_labels,
            "values": distribution_values,
            "points": [
                {"label": row.status, "value": int(row.count or 0)} for row in distribution_rows
            ],
        },
    }
