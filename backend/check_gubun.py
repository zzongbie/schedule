import psycopg2
from database import get_db_connection

def check_users_gubun():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute('''
                SELECT u.id, u.name, e.id AS emp_id, e.gubun, u.com_id
                FROM "user" u 
                LEFT JOIN employee e ON u.id = e.user_id;
            ''')
            print("User and Employee Info:")
            for row in cur.fetchall():
                print(row)
    finally:
        conn.close()

if __name__ == "__main__":
    check_users_gubun()
