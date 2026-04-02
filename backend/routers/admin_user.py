from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from database import get_db_connection
from psycopg2.extras import RealDictCursor
from datetime import datetime

router = APIRouter()

class UserBase(BaseModel):
    com_id: int
    name: str
    pw: str
    lock_cnt: Optional[int] = 0
    rest_chk: Optional[bool] = False

class UserCreate(UserBase):
    pass

class UserResponse(UserBase):
    id: int
    regtm: Optional[datetime] = None
    lsttm: Optional[datetime] = None
    token: Optional[str] = None

def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.get("/", response_model=List[UserResponse])
def get_users(db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute('SELECT * FROM "user" ORDER BY id ASC;')
            return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=UserResponse)
def create_user(user: UserCreate, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            # PostgreSQL requires "user" since user is a reserved word
            cur.execute(
                'INSERT INTO "user" (com_id, name, pw, lock_cnt, rest_chk, regtm) VALUES (%s, %s, %s, %s, %s, CURRENT_TIMESTAMP) RETURNING *;',
                (user.com_id, user.name, user.pw, user.lock_cnt, user.rest_chk)
            )
            new_user = cur.fetchone()
            db.commit()
            return new_user
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{user_id}", response_model=UserResponse)
def update_user(user_id: int, user: UserCreate, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                'UPDATE "user" SET com_id=%s, name=%s, pw=%s, lock_cnt=%s, rest_chk=%s WHERE id=%s RETURNING *;',
                (user.com_id, user.name, user.pw, user.lock_cnt, user.rest_chk, user_id)
            )
            updated_user = cur.fetchone()
            if not updated_user:
                raise HTTPException(status_code=404, detail="User not found")
            db.commit()
            return updated_user
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{user_id}")
def delete_user(user_id: int, db = Depends(get_db)):
    try:
        with db.cursor() as cur:
            cur.execute('DELETE FROM "user" WHERE id=%s;', (user_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="User not found")
            db.commit()
            return {"message": "Deleted"}
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))
