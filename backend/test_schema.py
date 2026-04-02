import sys
sys.path.append('e:/schedule/backend')
from database import get_db_connection
try:
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM schedule LIMIT 0")
    print([desc[0] for desc in cur.description])
    conn.close()
except Exception as e:
    print("Error:", e)
