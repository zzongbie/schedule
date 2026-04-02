cd e:\schedule\backend

if (-not (Test-Path "venv")) {
    Write-Host "가상환경(venv)을 생성합니다..."
    python -m venv venv
}

Write-Host "가상환경을 활성화하고 패키지를 설치합니다..."
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

Write-Host "Uvicorn 서버를 실행합니다..."
uvicorn main:app --reload
