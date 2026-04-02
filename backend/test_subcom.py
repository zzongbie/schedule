import json
from database import get_db_connection
from psycopg2.extras import RealDictCursor

conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Check column types
        cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'subcom'")
        cols = cur.fetchall()
        print("Columns:", cols)
        
        # Insert test
        query = "INSERT INTO subcom (com_id, name, phone, email, gubun) VALUES (%s, %s, %s, %s, %s) RETURNING *"
        try:
            cur.execute(query, (1, 'Test Subcom', '010-1234', 'test@test', 'true'))
            res = cur.fetchone()
            print("Insert true string success:", res)
            conn.rollback()
        except Exception as e:
            print("Insert true string failed:", str(e))
            conn.rollback()
            
        try:
            cur.execute(query, (1, 'Test Subcom', '010-1234', 'test@test', True))
            res = cur.fetchone()
            print("Insert True bool success:", res)
            conn.rollback()
        except Exception as e:
            print("Insert True bool failed:", str(e))
            conn.rollback()
            
finally:
    conn.close()
