import requests

try:
    res = requests.post("http://localhost:8000/api/v1/users/login", json={"user_id": "admin", "password": "123"})
    print("RES:", res.status_code, res.text)
except Exception as e:
    print(e)
