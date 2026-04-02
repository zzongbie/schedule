import psycopg2
from database import get_db_connection

def test_insert_employee():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Try to insert a dummy employee for com_id 1
            try:
                cur.execute("""
                    INSERT INTO employee (com_id, name, position, email) 
                    VALUES (%s, %s, %s, %s) RETURNING id;
                """, (1, 'Test Employee', 'Dev', 'test@example.com'))
                emp_id = cur.fetchone()[0]
                print(f"Successfully inserted employee with ID: {emp_id}")
                
                # Try to insert into predata
                cur.execute("""
                    INSERT INTO predata (emp_id, com_id, otp) 
                    VALUES (%s, %s, %s) RETURNING *;
                """, (emp_id, 1, '123456'))
                print("Successfully inserted into predata")
                
                conn.commit()
            except Exception as e:
                print(f"Error during insert: {e}")
                conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    test_insert_employee()
