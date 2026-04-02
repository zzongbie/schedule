import psycopg2
from psycopg2.extras import RealDictCursor
import os

# TODO: 실제 사용하시는 PostgreSQL 계정 정보로 변경해주세요.
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "scheduler")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "admin")
DB_PORT = os.environ.get("DB_PORT", "5432")

def get_db_connection():
    """
    PostgreSQL 데이터베이스 연결을 생성하고 반환합니다.
    RealDictCursor를 사용하여 결과를 딕셔너리 형태로 받습니다. (JSON 응답에 유리함)
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT
        )
        return conn
    except Exception as e:
        print(f"데이터베이스 연결 오류: {e}")
        raise e
