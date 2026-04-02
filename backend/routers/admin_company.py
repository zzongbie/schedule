from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from database import get_db_connection
from psycopg2.extras import RealDictCursor
from typing import List, Optional

router = APIRouter()

class CompanyBase(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None

class CompanyCreate(CompanyBase):
    pass

class CompanyResponse(CompanyBase):
    id: int

def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.get("/", response_model=List[CompanyResponse])
def get_companies(db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, name, phone, email FROM company ORDER BY id ASC;")
            return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=CompanyResponse)
def create_company(company: CompanyCreate, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO company (name, phone, email) VALUES (%s, %s, %s) RETURNING id, name, phone, email;",
                (company.name, company.phone, company.email)
            )
            new_comp = cur.fetchone()
            db.commit()
            return new_comp
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{company_id}", response_model=CompanyResponse)
def update_company(company_id: int, company: CompanyCreate, db = Depends(get_db)):
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "UPDATE company SET name=%s, phone=%s, email=%s WHERE id=%s RETURNING id, name, phone, email;",
                (company.name, company.phone, company.email, company_id)
            )
            updated_comp = cur.fetchone()
            if not updated_comp:
                raise HTTPException(status_code=404, detail="Company not found")
            db.commit()
            return updated_comp
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{company_id}")
def delete_company(company_id: int, db = Depends(get_db)):
    try:
        with db.cursor() as cur:
            cur.execute("DELETE FROM company WHERE id=%s;", (company_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Company not found")
            db.commit()
            return {"message": "Deleted"}
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))
