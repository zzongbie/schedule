import psycopg2
from database import get_db_connection

def check_admin():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute('SELECT id, name, com_id FROM "user" WHERE name = \'admin\';')
            print("Admin User Info:")
            print(cur.fetchone())
    finally:
        conn.close()

if __name__ == "__main__":
    check_admin()
