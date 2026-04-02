import psycopg2
from database import get_db_connection

def inspect_table():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Check for NOT NULL columns without defaults
            cur.execute("""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns
                WHERE table_name = 'schedule'
                AND is_nullable = 'NO'
                AND column_default IS NULL;
            """)
            print("NOT NULL Columns without default:")
            print(cur.fetchall())

            # Check for primary key
            cur.execute("""
                SELECT
                    tc.constraint_name, 
                    kcu.column_name
                FROM 
                    information_schema.table_constraints AS tc 
                    JOIN information_schema.key_column_usage AS kcu
                      ON tc.constraint_name = kcu.constraint_name
                      AND tc.table_schema = kcu.table_schema
                WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_name='schedule';
            """)
            print("Primary Key:")
            print(cur.fetchall())
            
            # Check for all constraints
            cur.execute("""
                SELECT conname, contype, pg_get_constraintdef(oid) 
                FROM pg_constraint 
                WHERE conrelid = 'schedule'::regclass;
            """)
            print("All Constraints:")
            for row in cur.fetchall():
                print(row)
                
    finally:
        conn.close()

if __name__ == "__main__":
    inspect_table()
