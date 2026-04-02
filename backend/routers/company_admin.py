from fastapi import APIRouter, HTTPException, Depends, Path, Body
from typing import Dict, Any, List
from database import get_db_connection
from psycopg2.extras import RealDictCursor
import random
import string
import smtplib
from email.mime.text import MIMEText
import os

router = APIRouter()

def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

ALLOWED_ENTITIES = {
    "dept": {"table": "dept", "pk": "id", "fields": ["name", "pid", "emp_id"]},
    "team": {"table": "team", "pk": "id", "fields": ["name", "dept_id", "emp_id"]},
    "subcom": {"table": "subcom", "pk": "id", "fields": ["name", "phone", "email", "gubun"]},
    "subcommap": {"table": "subcominfo", "pk": "subcom_id", "fields": ["addr", "sido", "sigungu", "dong", "mail"]},
    "employee": {"table": "employee", "pk": "id", "fields": ["name", "position", "email", "phone", "status", "auth", "team_id", "dept_id", "scm_id", "user_id", "gubun", "join_dt", "quit_dt", "status_s_dt"]},
    "company_calendar": {"table": "company_calendar", "pk": "adate", "fields": ["flag", "memo"]},
    "meta": {"table": "meta", "pk": "code", "fields": ["name", "orderno", "memo", "gcode"]},
}

def send_otp_email(to_email: str, otp: str):
    print(f"====== OTP EMAIL TO {to_email} ======")
    print(f"OTP: {otp}")
    print(f"====================================")
    smtp_server = os.environ.get("SMTP_SERVER", "")
    smtp_port = int(os.environ.get("SMTP_PORT", 587))
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_password = os.environ.get("SMTP_PASSWORD", "")
    
    if smtp_server and smtp_user and smtp_password:
        try:
            msg = MIMEText(f"귀하의 사내 스케줄러 등록 OTP는 다음과 같습니다:\n\n{otp}\n\n회원가입시 입력해주세요.")
            msg['Subject'] = '사내 스케줄러 등록 OTP 안내'
            msg['From'] = smtp_user
            msg['To'] = to_email
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
        except Exception as e:
            print(f"Failed to send email: {e}")

@router.get("/{company_id}/{entity}", response_model=List[Dict[str, Any]])
def get_entity_list(company_id: int, entity: str = Path(...), db=Depends(get_db)):
    if entity not in ALLOWED_ENTITIES:
        raise HTTPException(status_code=400, detail="Invalid entity")
    
    table_info = ALLOWED_ENTITIES[entity]
    table = table_info["table"]
    
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            if entity == "subcommap":
                cur.execute(f"SELECT m.*, s.name as subcom_name FROM {table} m JOIN subcom s ON m.subcom_id = s.id WHERE m.com_id=%s ORDER BY m.{table_info['pk']} ASC;", (company_id,))
            else:
                cur.execute(f"SELECT * FROM {table} WHERE com_id=%s ORDER BY {table_info['pk']} ASC;", (company_id,))
            records = cur.fetchall()
            # For company_calendar, pk is adate (date object), map to string id to be compatible with frontend generic 'id' handling
            if entity == "company_calendar":
                for r in records:
                    r['id'] = r['adate']
            elif entity == "subcommap":
                for r in records:
                    r['id'] = r['subcom_id']
            return records
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{company_id}/{entity}")
def create_entity(company_id: int, entity: str = Path(...), data: Dict[str, Any] = Body(...), db=Depends(get_db)):
    if entity not in ALLOWED_ENTITIES:
        raise HTTPException(status_code=400, detail="Invalid entity")
    
    table_info = ALLOWED_ENTITIES[entity]
    table = table_info["table"]
    fields = table_info["fields"]
    
    insert_fields = ["com_id"]
    values = [company_id]
    
    # company_calendar uses adate as PK implicitly provided in data
    if entity == "company_calendar" and "adate" in data and data["adate"]:
        insert_fields.append("adate")
        values.append(data["adate"])
    elif entity == "subcommap" and "subcom_id" in data and data["subcom_id"]:
        insert_fields.append("subcom_id")
        values.append(data["subcom_id"])

    # Convert gubun to 1/0 for smallint
    if entity == "subcom" and "gubun" in data:
        data["gubun"] = 1 if data["gubun"] in [True, "true", "1", 1] else 0
        
    for f in fields:
        if f in data and data[f] is not None and data[f] != '':
            insert_fields.append(f)
            values.append(data[f])
            
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            if entity == "subcom" and data.get("gubun") == 1:
                cur.execute("UPDATE subcom SET gubun = 0 WHERE com_id=%s", (company_id,))

            query = f"INSERT INTO {table} ({', '.join(insert_fields)}) VALUES ({', '.join(['%s']*len(insert_fields))}) RETURNING *;"
            cur.execute(query, tuple(values))
            new_record = cur.fetchone()
            
            # 사원 등록인 경우 predata 및 OTP 생성
            if entity == "employee":
                emp_id = new_record["id"]
                to_email = new_record.get("email")
                # 6자리 랜덤 숫자 OTP 생성
                otp = ''.join(random.choices(string.digits, k=6))
                
                # predata 테이블에 저장
                cur.execute(
                    "INSERT INTO predata (emp_id, com_id, otp) VALUES (%s, %s, %s)",
                    (emp_id, company_id, otp)
                )
                
                # 이메일 발송
                if to_email:
                    send_otp_email(to_email, otp)
                    
            db.commit()
            return new_record
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{company_id}/{entity}/{item_id}")
def update_entity(company_id: int, item_id: str, entity: str = Path(...), data: Dict[str, Any] = Body(...), db=Depends(get_db)):
    if entity not in ALLOWED_ENTITIES:
        raise HTTPException(status_code=400, detail="Invalid entity")
        
    table_info = ALLOWED_ENTITIES[entity]
    table = table_info["table"]
    fields = table_info["fields"]
    pk = table_info["pk"]
    
    # Convert gubun to 1/0 for smallint
    if entity == "subcom" and "gubun" in data:
        data["gubun"] = 1 if data["gubun"] in [True, "true", "1", 1] else 0

    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            if entity == "employee" and "status" in data:
                cur.execute(f"SELECT status FROM {table} WHERE com_id=%s AND {pk}=%s", (company_id, item_id))
                old_record = cur.fetchone()
                if old_record and old_record.get("status") != data["status"]:
                    from datetime import datetime
                    data["status_s_dt"] = datetime.now().strftime("%Y%m%d")

            update_fields = []
            values = []
            for f in fields:
                if f in data and data[f] is not None and data[f] != '':
                    update_fields.append(f"{f}=%s")
                    values.append(data[f])
                    
            if not update_fields:
                return {"message": "Nothing to update"}
                
            values.extend([company_id, item_id])
    
            if entity == "subcom" and data.get("gubun") == 1:
                cur.execute("UPDATE subcom SET gubun = 0 WHERE com_id=%s AND id != %s", (company_id, item_id))

            query = f"UPDATE {table} SET {', '.join(update_fields)} WHERE com_id=%s AND {pk}=%s RETURNING *;"
            cur.execute(query, tuple(values))
            updated_record = cur.fetchone()
            if not updated_record:
                raise HTTPException(status_code=404, detail="Item not found")
            db.commit()
            return updated_record
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{company_id}/{entity}/{item_id}")
def delete_entity(company_id: int, item_id: str, entity: str = Path(...), db=Depends(get_db)):
    if entity not in ALLOWED_ENTITIES:
        raise HTTPException(status_code=400, detail="Invalid entity")
        
    table_info = ALLOWED_ENTITIES[entity]
    table = table_info["table"]
    pk = table_info["pk"]
    
    try:
        with db.cursor() as cur:
            cur.execute(f"DELETE FROM {table} WHERE com_id=%s AND {pk}=%s;", (company_id, item_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Item not found")
            db.commit()
            return {"message": "Deleted"}
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))
