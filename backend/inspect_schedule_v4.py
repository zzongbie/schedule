import psycopg2
from database import get_db_connection

def inspect_table():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Check for is_identity
            cur.execute("""
                SELECT column_name, is_identity, column_default, is_nullable
                FROM information_schema.columns
                WHERE table_name = 'schedule'
                AND column_name = 'idx';
            """)
            print("IDX Info:")
            print(cur.fetchone())

            # Check all table columns
            cur.execute("""
                SELECT column_name, data_type, is_nullable, column_default, is_identity
                FROM information_schema.columns
                WHERE table_name = 'schedule'
                ORDER BY ordinal_position;
            """)
            print("All Columns:")
            for row in cur.fetchall():
                print(row)
                
    finally:
        conn.close()

if __name__ == "__main__":
    inspect_table()
