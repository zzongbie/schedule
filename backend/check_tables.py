import psycopg2
from database import get_db_connection

conn = get_db_connection()
try:
    with conn.cursor() as cur:
        for t in ["schedule", "view_employee", "schedule_employee"]:
            try:
                cur.execute(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{t}'")
                print(f"--- {t} ---")
                print(cur.fetchall())
            except Exception as e:
                print(f"{t} error: {e}")
                conn.rollback()
finally:
    conn.close()
