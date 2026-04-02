import psycopg2
import sys

def check_tables():
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="scheduler",
            user="postgres",
            password="admin",
            port="5432"
        )
        cur = conn.cursor()
        
        # Get all tables
        cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        tables = cur.fetchall()
        print("=== Tables ===")
        for table in tables:
            print(f"- {table[0]}")
            
            # Get columns for each table
            cur.execute(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{table[0]}'")
            columns = cur.fetchall()
            for col in columns:
                print(f"    - {col[0]} ({col[1]})")
                
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_tables()
