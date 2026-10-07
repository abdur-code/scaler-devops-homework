import os
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# Fix: the tasks table is created in the app's startup event, and TestClient only runs
# startup events when it is used as a context manager (`with TestClient(app)`). Without
# this, POST /api/tasks failed with "no such table: tasks" on a clean checkout.
@pytest.fixture(autouse=True, scope="module")
def run_startup_events():
    with client:
        yield

def test_health():
    assert client.get("/health").json() == {"status": "UP"}

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"

def test_create_task_validation():
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    assert response.json()["title"] == "Deploy application"
