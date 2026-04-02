import psycopg2

def check_employee():
    try:
        conn = psycopg2.connect(host="localhost", database="scheduler", user="postgres", password="admin", port="5432")
        cur = conn.cursor()
        cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'employee'")
        for col in cur.fetchall():
            print(col)
        conn.close()
    except Exception as e:
        print(e)

if __name__ == "__main__":
    check_employee()
