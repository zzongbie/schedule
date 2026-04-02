import psycopg2
from database import get_db_connection

conn = get_db_connection()
try:
    with conn.cursor() as cur:
        cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'employee'")
        print("Employee Columns:", cur.fetchall())
finally:
    conn.close()
