import psycopg2
from psycopg2.extras import RealDictCursor
import os

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "scheduler")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "admin")
DB_PORT = os.environ.get("DB_PORT", "5432")

def check_table_nullability(table_name):
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(f"""
                SELECT column_name, is_nullable, data_type, column_default, character_maximum_length, is_identity
                FROM information_schema.columns
                WHERE table_name = '{table_name}'
                ORDER BY ordinal_position;
            """)
            cols = cur.fetchall()
            print(f"--- Columns of {table_name} ---")
            for col in cols:
                print(f"{col['column_name']}: {col['data_type']}({col['character_maximum_length']}) (Nullable: {col['is_nullable']}, Default: {col['column_default']}, Identity: {col['is_identity']})")
    finally:
        conn.close()

if __name__ == "__main__":
    check_table_nullability('schedule')
