from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from database import get_db_connection
from psycopg2.extras import RealDictCursor
from typing import List, Optional

router = APIRouter()

class MetaBase(BaseModel):
    com_id: int
    code: str
    name: Optional[str] = None
    orderno: Optional[int] = None
    memo: Optional[str] = None
    gcode: Optional[str] = None

def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.get("/", response_model=List[MetaBase])
def get_metas(db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT com_id, orderno, code, name, memo, gcode FROM meta ORDER BY com_id ASC, code ASC, orderno ASC;")
            return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=MetaBase)
def create_meta(meta: MetaBase, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO meta (com_id, code, name, orderno, memo, gcode) VALUES (%s, %s, %s, %s, %s, %s) RETURNING com_id, orderno, code, name, memo, gcode;",
                (meta.com_id, meta.code, meta.name, meta.orderno, meta.memo, meta.gcode)
            )
            new_meta = cur.fetchone()
            db.commit()
            return new_meta
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{com_id}/{code}", response_model=MetaBase)
def update_meta(com_id: int, code: str, meta: MetaBase, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "UPDATE meta SET name=%s, orderno=%s, memo=%s, gcode=%s WHERE com_id=%s AND code=%s RETURNING com_id, orderno, code, name, memo, gcode;",
                (meta.name, meta.orderno, meta.memo, meta.gcode, com_id, code)
            )
            updated_meta = cur.fetchone()
            if not updated_meta:
                raise HTTPException(status_code=404, detail="Meta not found")
            db.commit()
            return updated_meta
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{com_id}/{code}")
def delete_meta(com_id: int, code: str, db = Depends(get_db)):
    try:
        with db.cursor() as cur:
            cur.execute("DELETE FROM meta WHERE com_id=%s AND code=%s;", (com_id, code))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Meta not found")
            db.commit()
            return {"message": "Deleted"}
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))
