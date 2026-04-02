import sys
sys.path.append('e:/schedule/backend')
from database import get_db_connection
from psycopg2.extras import RealDictCursor
conn = get_db_connection()
with conn.cursor(cursor_factory=RealDictCursor) as cur:
    cur.execute("""
        SELECT s.id, s.com_id, s.ins_id, e.name AS ins_name, s.type, m.name AS type_name, s."name", 
               s.detail, s.highlight, s.view_type, s.scope_type, s.regtm, s.idx,
               s.start, s.start_time, s.end, s.end_time
        FROM schedule s
        LEFT JOIN employee e ON s.ins_id = e.id AND s.com_id = e.com_id
        LEFT JOIN meta m ON s.com_id = m.com_id AND s.type = m.code
        WHERE s.com_id = 2 
        ORDER BY s."start" ASC, s.start_time ASC;
    """)
    schedules = cur.fetchall()
    print("row:", schedules[0])
