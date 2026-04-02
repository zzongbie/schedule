import psycopg2
from database import get_db_connection

def test_router_like_insert():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Using same column list as schedules.py
            # Note: idx is omitted because it's now IDENTITY
            try:
                cur.execute(
                    """
                    INSERT INTO schedule (com_id, ins_id, type, "name", "start", start_time, "end", end_time, detail, highlight, view_type)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING idx, com_id, ins_id, type, "name", "start", start_time, "end", end_time, detail, highlight, view_type, regtm;
                    """,
                    (1, 1, 'T001', 'Test Scheduled 2', '2026-03-17', '11:00', '2026-03-17', '12:00', 'Success test', True, 1)
                )
                res = cur.fetchone()
                print(f"Success! Res: {res}")
                conn.commit()
            except Exception as e:
                print(f"Failed again: {e}")
                conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    test_router_like_insert()
