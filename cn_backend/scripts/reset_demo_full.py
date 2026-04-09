"""Reset the full database and bootstrap deterministic demo data.

Usage:
  python scripts/reset_demo_full.py
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from database import SessionLocal
from scripts.reset_seed_demo import clear_all, seed


def main() -> None:
    db = SessionLocal()
    try:
        clear_all(db)
        seed(db)
        print("RESET_DEMO_FULL_DONE")
    finally:
        db.close()


if __name__ == "__main__":
    main()
