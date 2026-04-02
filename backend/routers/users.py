from fastapi import APIRouter, HTTPException, Depends, Body
from pydantic import BaseModel
import datetime
from database import get_db_connection
from psycopg2.extras import RealDictCursor

router = APIRouter()

from typing import Optional

class LoginRequest(BaseModel):
    user_id: str
    password: str

class SignupRequest(BaseModel):
    user_id: str
    password: str
    otp: str

class LoginResponse(BaseModel):
    message: str
    user_id: str
    id: Optional[int] = None
    emp_id: Optional[int] = None
    gubun: Optional[str] = None
    auth: Optional[str] = None
    position: Optional[str] = None
    com_id: Optional[int] = None

# 의존성 주입
def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.post("/login", response_model=LoginResponse)
def login(req: LoginRequest, db = Depends(get_db)):
    """로그인 API (간이 구현)"""
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            # "user" 테이블과 "employee" 테이블 조인하여 gubun 값을 가져옴
            cur.execute('''
                SELECT u.id, u.name, u.pw, u.com_id, e.gubun, e.auth, e.position, e.id AS emp_id
                FROM "user" u 
                LEFT JOIN employee e ON u.id = e.user_id 
                WHERE u.name = %s;
            ''', (req.user_id,))
            user = cur.fetchone()
            
            # 유저가 없거나 비밀번호가 다르면 에러 (pw 컬럼과 비교)
            if not user or user['pw'] != req.password:
                raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 틀렸습니다.")
                
            # admin 로그인의 경우 gubun 값이 없어도 A001로 처리
            gubun = user['gubun']
            if not gubun and user['name'] == 'admin':
                gubun = 'A001'
            elif not gubun:
                gubun = 'A002' # 기본값
                
            return {
                "message": "로그인 성공", 
                "user_id": user['name'], 
                "id": user['id'],
                "emp_id": user['emp_id'],
                "gubun": gubun,
                "auth": user['auth'],
                "position": user['position'],
                "com_id": user['com_id']
            }
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")

@router.post("/check_id")
def check_id(user_id: str = Body(..., embed=True), db = Depends(get_db)):
    try:
        with db.cursor() as cur:
            cur.execute('SELECT id FROM "user" WHERE name = %s;', (user_id,))
            if cur.fetchone():
                return {"available": False, "message": "이미 사용 중인 아이디입니다."}
            return {"available": True, "message": "사용 가능한 아이디입니다."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/signup")
def signup(req: SignupRequest, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. OTP 확인
            cur.execute('SELECT emp_id, com_id FROM predata WHERE otp = %s;', (req.otp,))
            predata = cur.fetchone()
            
            if not predata:
                raise HTTPException(status_code=400, detail="OTP가 일치하지 않거나 유효하지 않습니다.")
                
            emp_id = predata['emp_id']
            com_id = predata['com_id']
            
            # 2. 아이디 중복 확인
            cur.execute('SELECT id FROM "user" WHERE name = %s;', (req.user_id,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="이미 사용 중인 아이디입니다.")
            
            # 3. User 생성
            # 레코드 생성
            now = datetime.datetime.now()
            cur.execute(
                '''INSERT INTO "user" (name, pw, com_id, regtm) 
                   VALUES (%s, %s, %s, %s) RETURNING id;''',
                (req.user_id, req.password, com_id, now)
            )
            new_user_id = cur.fetchone()['id']
            
            # 4. Employee 업데이트
            cur.execute('UPDATE employee SET user_id = %s WHERE id = %s;', (new_user_id, emp_id))
            
            # 5. predata 정리
            cur.execute('DELETE FROM predata WHERE emp_id = %s;', (emp_id,))
            
            db.commit()
            return {"message": "회원가입이 완료되었습니다."}
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"회원가입 오류: {str(e)}")
