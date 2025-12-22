import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch, AsyncMock
import sys
import os

# Ensure project root is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from api_server import app

client = TestClient(app)

@pytest.fixture
def mock_auth():
    # Patching where it is imported in the router files
    with patch("routers.vertex_routes.get_user_id_from_request", return_value="test_user"), \
         patch("routers.byok_routes.get_user_id_from_request", return_value="test_user"):
        yield

@pytest.fixture
def mock_credit_service():
    with patch("routers.vertex_routes.get_credit_service") as mock:
        service = MagicMock()
        mock.return_value = service
        yield service

@pytest.fixture
def mock_user_settings():
    with patch("routers.byok_routes.UserSettings") as mock:
        settings = MagicMock()
        mock.return_value = settings
        yield settings

@pytest.fixture
def mock_wrapper():
    # Patch ADKModelWrapper in both router modules
    with patch("routers.vertex_routes.ADKModelWrapper") as mock1, \
         patch("routers.byok_routes.ADKModelWrapper") as mock2:
        
        wrapper_instance = MagicMock()
        # Mock generate as async
        wrapper_instance.generate = AsyncMock()
        wrapper_instance.generate.return_value = MagicMock(
            text="Test response",
            model_name="test-model",
            latency_ms=100,
            mode="vertex_ai", # Default to vertex for tests
            error=None
        )
        
        mock1.return_value = wrapper_instance
        mock2.return_value = wrapper_instance
        
        yield wrapper_instance

def test_vertex_route_success(mock_auth, mock_credit_service, mock_wrapper):
    # Setup credit balance
    mock_credit_service.get_balance.return_value = {"ok": True, "balance": 10}
    
    response = client.post("/vertex/generate", json={"prompt": "Hello"})
    
    assert response.status_code == 200
    assert response.json()["text"] == "Test response"
    # wrapper returns mode="vertex_ai", so credits_used should be True
    assert bool(response.json()["credits_used"]) is True
    
    mock_credit_service.get_balance.assert_called_with("test_user")

def test_vertex_route_insufficient_credits(mock_auth, mock_credit_service):
    mock_credit_service.get_balance.return_value = {"ok": True, "balance": 0}
    
    response = client.post("/vertex/generate", json={"prompt": "Hello"})
    
    assert response.status_code == 402
    assert "Insufficient credits" in response.json()["detail"]

def test_byok_route_success(mock_auth, mock_user_settings, mock_wrapper):
    mock_user_settings.has_custom_api_key.return_value = True
    
    # Mock wrapper to return BYOK mode
    mock_wrapper.generate.return_value.mode = "byok"
    
    response = client.post("/byok/generate", json={"prompt": "Hello"})
    
    assert response.status_code == 200
    assert response.json()["text"] == "Test response"
    assert bool(response.json()["credits_used"]) is False

def test_byok_route_no_key(mock_auth, mock_user_settings):
    mock_user_settings.has_custom_api_key.return_value = False
    
    response = client.post("/byok/generate", json={"prompt": "Hello"})
    
    assert response.status_code == 403
    assert "No custom API key" in response.json()["detail"]
