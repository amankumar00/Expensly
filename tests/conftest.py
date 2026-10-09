import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, get_session
from sqlmodel import Session, select
from app.models import User, Transaction, ChatMessageRecord
import time

@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c

@pytest.fixture(scope="function")
def test_user(client):
    # Setup: Create a unique test user
    email = f"test_{int(time.time())}_{id(client)}@example.com"
    res = client.post("/auth/signup", json={
        "name": "Test User",
        "email": email,
        "password": "strongpassword"
    })
    assert res.status_code == 200
    token = res.json()["access_token"]
    user_id = res.json()["user"]["id"]
    
    yield {"email": email, "token": token, "id": user_id, "headers": {"Authorization": f"Bearer {token}"}}
    
    # Teardown: Delete the user and all their data to keep DB clean
    with Session(engine) as session:
        # Delete transactions
        session.query(Transaction).filter(Transaction.user_id == user_id).delete()
        # Delete chat messages
        session.query(ChatMessageRecord).filter(ChatMessageRecord.user_id == user_id).delete()
        # Delete user
        session.query(User).filter(User.id == user_id).delete()
        session.commit()
