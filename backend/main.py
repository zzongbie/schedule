from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import schedules, users, admin_company, admin_meta, company_admin, admin_user

app = FastAPI(
    title="Schedule App API (Backman)",
    description="스케줄 관리 앱을 위한 백엔드 API 서버 (FastAPI + PostgreSQL 직접 쿼리)",
    version="1.0.0"
)

# CORS 설정: Flutter 앱(프론트엔드)에서 API를 호출할 수 있도록 허용합니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 중에는 전부 허용, 운영 환경에서는 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(schedules.router, prefix="/api/v1/schedules", tags=["Schedules"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(admin_company.router, prefix="/api/v1/admin/company", tags=["Admin (Company)"])
app.include_router(admin_meta.router, prefix="/api/v1/admin/meta", tags=["Admin (Meta)"])
app.include_router(company_admin.router, prefix="/api/v1/company", tags=["Company Admin"])
app.include_router(admin_user.router, prefix="/api/v1/admin/user", tags=["Admin (User)"])

@app.get("/")
def read_root():
    return {"message": "백맨(Backman) 서버 정상 구동 중입니다. (FastAPI)"}

if __name__ == "__main__":
    import uvicorn
    # 터미널에서 실행 시: uvicorn main:app --reload
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
