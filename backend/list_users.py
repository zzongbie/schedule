import psycopg2
from database import get_db_connection

def list_users():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute('SELECT id, name, com_id FROM "user";')
            print("Users in DB:")
            for row in cur.fetchall():
                print(row)
    finally:
        conn.close()

if __name__ == "__main__":
    list_users()
