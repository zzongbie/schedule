import psycopg2
from database import get_db_connection

def check_table():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'schedule_target');")
            exists = cur.fetchone()[0]
            print(f"schedule_target exists: {exists}")
            
            if exists:
                cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'schedule_target';")
                print("Columns:")
                print(cur.fetchall())
    finally:
        conn.close()

if __name__ == "__main__":
    check_table()
