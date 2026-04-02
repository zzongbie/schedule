from fastapi import HTTPException
from pydantic import BaseModel
from typing import List, Optional
from database import get_db_connection
from psycopg2.extras import RealDictCursor
from datetime import datetime

class ScheduleTarget(BaseModel):
    target_id: int
    scope_type: int

class ScheduleCreate(BaseModel):
    com_id: int
    ins_id: int
    type: str
    name: str
    start: str
    start_time: str
    end: str
    end_time: str
    detail: Optional[str] = None
    highlight: bool = False
    view_type: bool = True
    targets: Optional[List[ScheduleTarget]] = None

def test_create_schedule():
    # Mimic the payload from frontend
    schedule = ScheduleCreate(
        com_id=1,
        ins_id=1,
        type="T001",
        name="Test from Script",
        start="2026-03-17",
        start_time="10:00",
        end="2026-03-17",
        end_time="11:00",
        detail="Testing insertion",
        highlight=False,
        view_type=True
    )
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            try:
                cur.execute(
                    """
                    INSERT INTO schedule (com_id, ins_id, type, "name", "start", start_time, "end", end_time, detail, highlight, view_type)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING idx AS id, com_id, ins_id, type, "name", 
                              "start"::text, start_time, "end"::text, end_time, 
                              detail, highlight, view_type, regtm;
                    """,
                    (
                        schedule.com_id, schedule.ins_id, schedule.type, schedule.name, 
                        schedule.start, schedule.start_time, schedule.end, schedule.end_time, 
                        schedule.detail, schedule.highlight, 1 if schedule.view_type else 0
                    )
                )
                new_schedule = cur.fetchone()
                print("Insertion Result:")
                print(new_schedule)
                conn.commit()
            except Exception as e:
                print(f"Error during insertion: {e}")
                conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    test_create_schedule()
