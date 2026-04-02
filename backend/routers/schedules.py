from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from database import get_db_connection
from psycopg2.extras import RealDictCursor
from datetime import datetime
import json

router = APIRouter()

# Schema 정의 (Pydantic을 사용하여 입력값 검증)
class ScheduleTarget(BaseModel):
    target_id: int
    scope_type: int
    type: str
    name: str

class ScheduleCreate(BaseModel):
    com_id: int
    ins_id: int
    type: str # 직무 (meta T)
    name: str # 일정명
    start: str # YYYY-MM-DD
    start_time: str # HH:mm
    end: str # YYYY-MM-DD
    end_time: str # HH:mm
    detail: Optional[str] = None
    highlight: bool = False
    view_type: int = 1 # 0: 나만보기, 1: 전체, 2: 특정대상
    scope_type: Optional[str] = None
    targets: Optional[List[ScheduleTarget]] = None
    executors: Optional[List[int]] = None

class ScheduleResponse(BaseModel):
    id: str
    com_id: int
    ins_id: int
    ins_name: Optional[str] = None # 작성자 이름 추가
    type: str # 직무 (meta T)
    type_name: Optional[str] = None # 직무명
    name: str # 일정명
    start: str # YYYY-MM-DD
    start_time: str # HH:mm
    end: str # YYYY-MM-DD
    end_time: str # HH:mm
    detail: Optional[str] = None
    highlight: bool = False
    view_type: int = 1
    scope_type: Optional[str] = None
    targets: list = []
    regtm: Optional[datetime] = None
    executors: list = []

# 의존성 주입: DB 연결 가져오기 및 닫기
def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.get("/", response_model=List[ScheduleResponse])
def get_schedules(com_id: int, db = Depends(get_db)):
    """특정 회사의 모든 일정 조회"""
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("CREATE TABLE IF NOT EXISTS schedule_executor (schedule_id varchar(16), emp_id integer);")
            cur.execute("""
                SELECT s.id, s.com_id, s.ins_id, e.name AS ins_name, s.type, m.name AS type_name, s."name", 
                       s.detail, s.highlight, s.view_type, s.scope_type, s.regtm, s.idx,
                       s."start"::text AS start, s.start_time, s."end"::text AS end, s.end_time,
                       (SELECT COALESCE(json_agg(json_build_object('id', e2.id, 'name', e2.name)), '[]'::json)
                        FROM schedule_employee se
                        JOIN employee e2 ON se.emp_id = e2.id
                        WHERE se.sch_id = s.idx) AS executors
                FROM schedule s
                LEFT JOIN employee e ON s.ins_id = e.id AND s.com_id = e.com_id
                LEFT JOIN meta m ON s.com_id = m.com_id AND s.type = m.code
                WHERE s.com_id = %s 
                ORDER BY s."start" ASC, s.start_time ASC;
            """, (com_id,))
            schedules = cur.fetchall()
            for s in schedules:
                if not s.get("id"): s["id"] = "0"
                # Parse scope_type separator
                targets = []
                group_depts = set()
                group_teams = set()
                group_scms = set()
                
                stype = s.get("scope_type")
                if stype:
                    try:
                        scope_list = json.loads(stype)
                        for item in scope_list:
                            for k, v in item.items():
                                if k == "C002":
                                    group_depts.add(v)
                                    cur.execute("SELECT name FROM dept WHERE id = %s", (v,))
                                    row = cur.fetchone()
                                    targets.append({"scope_type": 2, "target_id": v, "type": "부서", "name": row["name"] if row else "부서"})
                                elif k == "C003":
                                    group_teams.add(v)
                                    cur.execute("SELECT name FROM team WHERE id = %s", (v,))
                                    row = cur.fetchone()
                                    targets.append({"scope_type": 3, "target_id": v, "type": "팀", "name": row["name"] if row else "팀"})
                                elif k == "C001":
                                    group_scms.add(v)
                                    cur.execute("SELECT name FROM scm WHERE id = %s", (v,))
                                    row = cur.fetchone()
                                    targets.append({"scope_type": 4, "target_id": v, "type": "지사/협력사", "name": row["name"] if row else "지사/협력사"})
                    except:
                        pass
                
                cur.execute("SELECT ve.emp_id, e.name, e.dept_id, e.team_id, e.scm_id FROM view_employee ve JOIN employee e ON ve.emp_id = e.id WHERE ve.sch_id = %s", (s["idx"],))
                for row in cur.fetchall():
                    if row["dept_id"] in group_depts: continue
                    if row["team_id"] in group_teams: continue
                    if row["scm_id"] in group_scms: continue
                    targets.append({"scope_type": 1, "target_id": row["emp_id"], "type": "직원", "name": row["name"]})

                s["targets"] = targets
                
                if s.get("start_time") and len(s["start_time"]) == 4 and ":" not in s["start_time"]:
                    s["start_time"] = s["start_time"][:2] + ":" + s["start_time"][2:]
                if s.get("end_time") and len(s["end_time"]) == 4 and ":" not in s["end_time"]:
                    s["end_time"] = s["end_time"][:2] + ":" + s["end_time"][2:]
                    
            return schedules
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"데이터베이스 조회 오류: {str(e)}")

@router.post("/", response_model=ScheduleResponse, status_code=201)
def create_schedule(schedule: ScheduleCreate, db = Depends(get_db)):
    """새로운 일정 생성"""
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Generate YYYYMMDD00000001 format ID
            today_str = datetime.now().strftime("%Y%m%d")
            cur.execute(
                "SELECT id FROM schedule WHERE id LIKE %s ORDER BY id DESC LIMIT 1",
                (today_str + "%",)
            )
            last_record = cur.fetchone()
            
            if last_record and last_record["id"]:
                last_id = last_record["id"]
                try:
                    seq = int(last_id[-8:]) + 1
                except ValueError:
                    seq = 1
                new_id = f"{today_str}{seq:08d}"
            else:
                new_id = f"{today_str}00000001"

            # Calculate scope_type str (JSON format)
            scope_str = None
            if schedule.view_type == 2 and schedule.targets:
                scope_list = []
                for t in schedule.targets or []:
                    if t.scope_type == 2: scope_list.append({"C002": t.target_id})
                    elif t.scope_type == 3: scope_list.append({"C003": t.target_id})
                    elif t.scope_type == 4: scope_list.append({"C001": t.target_id})
                if scope_list:
                    scope_str = json.dumps(scope_list)
                    
            # Fix start_time, end_time length for varchar(4) and detail varchar(10)
            db_start_time = str(schedule.start_time).replace(":", "")[:4] if schedule.start_time else ""
            db_end_time = str(schedule.end_time).replace(":", "")[:4] if schedule.end_time else ""
            db_detail = str(schedule.detail)[:10] if schedule.detail else None

            cur.execute("SELECT COALESCE(MAX(idx), 0) + 1 AS next_idx FROM schedule")
            next_idx_row = cur.fetchone()
            next_idx = next_idx_row["next_idx"]

            # 2. Insert record
            cur.execute(
                """
                INSERT INTO schedule (idx, id, com_id, ins_id, type, "name", "start", start_time, "end", end_time, detail, highlight, view_type, scope_type)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, com_id, ins_id, type, "name", 
                          "start"::text, start_time, "end"::text, end_time, 
                          detail, highlight, view_type, scope_type, regtm, idx;
                """,
                (
                    next_idx, new_id, schedule.com_id, schedule.ins_id, schedule.type, schedule.name, 
                    schedule.start, db_start_time, schedule.end, db_end_time, 
                    db_detail, schedule.highlight, schedule.view_type, scope_str
                )
            )
            new_schedule = cur.fetchone()
            new_idx = new_schedule["idx"]
            
            # Fetch author name
            cur.execute("SELECT name FROM employee WHERE id = %s AND com_id = %s", (schedule.ins_id, schedule.com_id))
            emp = cur.fetchone()
            new_schedule["ins_name"] = emp["name"] if emp else None

            if schedule.view_type == 2 and schedule.targets:
                emp_set = set()
                for t in schedule.targets or []:
                    if t.scope_type == 1: 
                        emp_set.add(t.target_id)
                    elif t.scope_type == 2:
                        cur.execute("SELECT id FROM employee WHERE dept_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                    elif t.scope_type == 3:
                        cur.execute("SELECT id FROM employee WHERE team_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                    elif t.scope_type == 4:
                        cur.execute("SELECT id FROM employee WHERE scm_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                
                for emp_id in emp_set:
                    cur.execute(
                        "INSERT INTO view_employee (com_id, sch_id, emp_id) VALUES (%s, %s, %s)",
                        (schedule.com_id, new_idx, emp_id)
                    )

            if schedule.executors:
                for emp_id in schedule.executors or []:
                    cur.execute(
                        "INSERT INTO schedule_employee (com_id, sch_id, emp_id) VALUES (%s, %s, %s)",
                        (schedule.com_id, new_idx, emp_id)
                    )
            
            cur.execute("""
                SELECT COALESCE(json_agg(json_build_object('id', e2.id, 'name', e2.name)), '[]'::json) AS execs
                FROM schedule_employee se JOIN employee e2 ON se.emp_id = e2.id WHERE se.sch_id = %s
            """, (new_idx,))
            execs_row = cur.fetchone()
            new_schedule["executors"] = execs_row["execs"] if execs_row else []
            new_schedule["targets"] = [{"scope_type": t.scope_type, "target_id": t.target_id, "type": t.type, "name": t.name} for t in (schedule.targets or [])]

            db.commit()
            return new_schedule
    except Exception as e:
        db.rollback()
        import traceback
        error_msg = f"Error during schedule creation: {str(e)}\n{traceback.format_exc()}"
        with open("e:/schedule/backend/error_log.txt", "a", encoding="utf-8") as f:
            f.write(f"\n[{datetime.now()}] {error_msg}\n")
        raise HTTPException(status_code=500, detail=f"데이터베이스 삽입 오류: {str(e)}")

@router.put("/{schedule_id}", response_model=ScheduleResponse)
def update_schedule(schedule_id: str, schedule: ScheduleCreate, db = Depends(get_db)):
    """일정 수정 (작성자와 동일할 경우에만)"""
    try:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT ins_id, idx FROM schedule WHERE id = %s", (schedule_id,))
            target = cur.fetchone()
            if not target:
                raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
            if target["ins_id"] != schedule.ins_id:
                raise HTTPException(status_code=403, detail="자신이 작성한 일정만 수정 가능합니다.")

            sch_idx = target["idx"]

            scope_str = None
            if schedule.view_type == 2 and schedule.targets:
                scope_list = []
                for t in schedule.targets or []:
                    if t.scope_type == 2: scope_list.append({"C002": t.target_id})
                    elif t.scope_type == 3: scope_list.append({"C003": t.target_id})
                    elif t.scope_type == 4: scope_list.append({"C001": t.target_id})
                if scope_list:
                    scope_str = json.dumps(scope_list)
                    
            db_start_time = schedule.start_time.replace(":", "")[:4] if schedule.start_time else ""
            db_end_time = schedule.end_time.replace(":", "")[:4] if schedule.end_time else ""
            db_detail = schedule.detail[:10] if schedule.detail else schedule.detail

            cur.execute(
                """
                UPDATE schedule 
                SET type = %s, "name" = %s, "start" = %s, start_time = %s, "end" = %s, end_time = %s, 
                    detail = %s, highlight = %s, view_type = %s, scope_type = %s
                WHERE id = %s AND com_id = %s
                RETURNING id, com_id, ins_id, type, "name", 
                          "start"::text, start_time, "end"::text, end_time, 
                          detail, highlight, view_type, scope_type, regtm, idx;
                """,
                (
                    schedule.type, schedule.name, 
                    schedule.start, db_start_time, schedule.end, db_end_time, 
                    db_detail, schedule.highlight, schedule.view_type, scope_str,
                    schedule_id, schedule.com_id
                )
            )
            updated_schedule = cur.fetchone()

            if not updated_schedule:
                raise HTTPException(status_code=404, detail="일정 업데이트 실패 또는 권한 없음")

            # Fetch author name
            cur.execute("SELECT name FROM employee WHERE id = %s AND com_id = %s", (updated_schedule["ins_id"], schedule.com_id))
            emp = cur.fetchone()
            updated_schedule["ins_name"] = emp["name"] if emp else None

            cur.execute("DELETE FROM view_employee WHERE sch_id = %s", (sch_idx,))
            if schedule.view_type == 2 and schedule.targets is not None:
                emp_set = set()
                for t in schedule.targets or []:
                    if t.scope_type == 1: 
                        emp_set.add(t.target_id)
                    elif t.scope_type == 2:
                        cur.execute("SELECT id FROM employee WHERE dept_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                    elif t.scope_type == 3:
                        cur.execute("SELECT id FROM employee WHERE team_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                    elif t.scope_type == 4:
                        cur.execute("SELECT id FROM employee WHERE scm_id = %s AND com_id = %s", (t.target_id, schedule.com_id))
                        for row in cur.fetchall():
                            emp_set.add(row["id"])
                
                for emp_id in emp_set:
                    cur.execute(
                        "INSERT INTO view_employee (com_id, sch_id, emp_id) VALUES (%s, %s, %s)",
                        (schedule.com_id, sch_idx, emp_id)
                    )

            cur.execute("DELETE FROM schedule_employee WHERE sch_id = %s", (sch_idx,))
            if schedule.executors:
                for emp_id in schedule.executors or []:
                    cur.execute(
                        "INSERT INTO schedule_employee (com_id, sch_id, emp_id) VALUES (%s, %s, %s)",
                        (schedule.com_id, sch_idx, emp_id)
                    )
                    
            cur.execute("""
                SELECT COALESCE(json_agg(json_build_object('id', e2.id, 'name', e2.name)), '[]'::json) AS execs
                FROM schedule_employee se JOIN employee e2 ON se.emp_id = e2.id WHERE se.sch_id = %s
            """, (sch_idx,))
            execs_row = cur.fetchone()
            updated_schedule["executors"] = execs_row["execs"] if execs_row else []
            updated_schedule["targets"] = [{"scope_type": t.scope_type, "target_id": t.target_id, "type": t.type, "name": t.name} for t in (schedule.targets or [])]

            db.commit()
            return updated_schedule
    except HTTPException as e:
        raise e
    except Exception as e:
        db.rollback()
        import traceback
        error_msg = f"Error during schedule update: {str(e)}\n{traceback.format_exc()}"
        with open("e:/schedule/backend/error_log.txt", "a", encoding="utf-8") as f:
            f.write(f"\n[{datetime.now()}] {error_msg}\n")
        raise HTTPException(status_code=500, detail=f"데이터베이스 수정 오류: {str(e)}")
