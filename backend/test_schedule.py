import psycopg2
from database import get_db_connection
from datetime import datetime

def test_insert_schedule():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Check current column names and types just in case
            cur.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_name = 'schedule'
                ORDER BY ordinal_position;
            """)
            cols = cur.fetchall()
            print("--- Table Columns ---")
            for col in cols:
                print(col)

            # Try to insert
            try:
                # Based on schedules.py: com_id, ins_id, type, name, start, start_time, end, end_time, detail, highlight, view_type
                # BUT based on schema, id and idx are required
                cur.execute("""
                    INSERT INTO schedule (com_id, ins_id, type, name, start, start_time, end, end_time, detail, highlight, view_type)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id;
                """, (1, 1, 'T001', 'Test Schedule', '2026-03-17', '10:00', '2026-03-17', '11:00', 'Test detail', False, 1))
                new_id = cur.fetchone()[0]
                print(f"Inserted Successfully! ID: {new_id}")
                conn.commit()
            except Exception as e:
                print(f"Insertion failed: {e}")
                conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    test_insert_schedule()
