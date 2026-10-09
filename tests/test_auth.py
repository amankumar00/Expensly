import time

def test_signup_success(client):
    email = f"auth_{int(time.time())}@example.com"
    res = client.post("/auth/signup", json={"name": "Alice", "email": email, "password": "pass"})
    assert res.status_code == 200
    assert "access_token" in res.json()

def test_signup_duplicate_email(client, test_user):
    # Try signing up with the same email as test_user
    res = client.post("/auth/signup", json={"name": "Bob", "email": test_user["email"], "password": "pass"})
    assert res.status_code == 400
    assert "already registered" in res.json()["detail"].lower()

def test_login_success(client, test_user):
    res = client.post("/auth/login", data={"username": test_user["email"], "password": "strongpassword"})
    assert res.status_code == 200
    assert "access_token" in res.json()

def test_login_wrong_password(client, test_user):
    res = client.post("/auth/login", data={"username": test_user["email"], "password": "wrong"})
    assert res.status_code == 400
    assert "incorrect" in res.json()["detail"].lower()

def test_protected_route_unauthorized(client):
    res = client.get("/users/me")
    assert res.status_code == 401
