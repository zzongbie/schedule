import sys
import os
sys.path.append('e:/schedule/backend')
from database import get_db_connection
from psycopg2.extras import RealDictCursor
conn = get_db_connection()
with conn.cursor(cursor_factory=RealDictCursor) as cur:
    cur.execute("SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name = 'schedule';")
    rows = cur.fetchall()
    for row in rows:
        print(row)
