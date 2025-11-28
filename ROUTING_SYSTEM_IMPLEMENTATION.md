# Vertex AI Routing System Implementation Documentation

## 1. Work Summary

### Overview
This document details the implementation of a comprehensive routing system for Vertex AI integrations. The system is designed to intelligently route requests based on user credit status and "Bring Your Own Key" (BYOK) ownership, ensuring secure, monitored, and scalable access to AI models.

### Objectives Achieved
- **ADK Model Wrapper**: Created a standardized wrapper for Agent Development Kit (ADK) models with robust error handling and monitoring.
- **Credited User Routing**: Implemented secure routing for users consuming platform credits, including validation and quota management.
- **BYOK User Routing**: Established isolated routing for users providing their own API keys, ensuring data privacy and separate quota usage.
- **System Monitoring**: Integrated comprehensive logging and metrics collection for performance and usage tracking.
- **Testing**: Developed and verified unit tests covering critical routing scenarios and edge cases.

### Timeline & Activities
- **Context Gathering**: Analyzed existing services (`metrics_service.py`, `user_settings.py`, `api_server.py`) to ensure architectural alignment.
- **Core Implementation**:
  - Extended metrics service for granular model usage tracking.
  - Developed `ADKModelWrapper` for standardized I/O.
  - Implemented dual routing paths (`vertex_routes.py`, `byok_routes.py`).
- **Integration**: Updated `api_server.py` to include new routers.
- **Testing & Refinement**: Created unit tests, identified and fixed error propagation issues in BYOK routing.

---

## 2. Implementation Details

### Process & Methodology
The implementation followed a modular, service-oriented architecture approach, leveraging FastAPI's dependency injection and middleware capabilities.

1.  **Standardization (Model Wrapper)**:
    - **Approach**: Implemented the Adapter pattern via `ADKModelWrapper` to normalize inputs (`ModelInput`) and outputs (`ModelOutput`).
    - **Functionality**: Handles mode determination (Vertex vs. BYOK), stream generation, and automatic metric recording.

2.  **Routing Logic**:
    - **Credited Users**: Routes verify user credit balance via `CreditService` (implied/mocked) and route to Vertex AI endpoints managed by the platform.
    - **BYOK Users**: Routes verify the existence of a custom API key in `UserSettings`. The request is then executed using the user's specific credentials, isolating their usage from the platform's quota.

3.  **Monitoring**:
    - **Approach**: Extended `metrics_service.py` to log specific events: `model_usage`, latency, token counts, and errors.
    - **Storage**: Metrics are persisted to Firestore for analysis and auditing.

### Challenges & Resolutions
-   **Challenge**: Error Propagation in BYOK Routes.
    -   *Issue*: Initial implementation caught all exceptions generically, causing `HTTP 403 Forbidden` (missing key) to be returned as `HTTP 500 Internal Server Error`.
    -   *Resolution*: Refactored `verify_byok_key` and route handlers to explicitly catch and re-raise `fastapi.HTTPException` before catching generic exceptions.

---

## 3. File Inventory

### New Files

| File Path | Purpose | Key Features |
| :--- | :--- | :--- |
| `services/model_wrapper.py` | ADK Model Adapter | `ADKModelWrapper` class, `ModelInput`/`ModelOutput` dataclasses, async generation support. |
| `routers/vertex_routes.py` | Credited User Routes | Endpoints for platform-managed model access, credit checks. |
| `routers/byok_routes.py` | BYOK User Routes | Endpoints for custom key usage, key validation middleware. |
| `tests/test_routing.py` | Unit Testing | Pytest suite for routing logic, mocking auth and external services. |

### Modified Files

| File Path | Modification | Purpose |
| :--- | :--- | :--- |
| `services/metrics_service.py` | Added `record_model_usage` | specific logging function for model latency, tokens, and errors. |
| `api_server.py` | Router Inclusion | Imported and mounted `vertex_router` and `byok_router`. |

### Referenced Files
-   `services/user_settings.py`: Used for retrieving and verifying encrypted BYOK keys.
-   `services/credit_service.py`: Referenced for credit management logic context.

---

## 4. Dependencies

The implementation relies on the following key libraries and frameworks:

-   **FastAPI**: Web framework for routing and dependency injection.
-   **Google Cloud AI Platform (Vertex AI)**: SDK for interacting with Gemini models.
-   **Firebase Admin**: Interaction with Firestore for metrics and settings.
-   **Pytest & Pytest-Asyncio**: Testing framework for async route handlers.
-   **Pydantic**: Data validation for API models (implied via FastAPI).

---

## 5. Testing Information

### Test Suite
-   **Location**: `tests/test_routing.py`
-   **Framework**: `pytest` with `pytest-asyncio`

### Test Cases
1.  **`test_vertex_route_success`**: Verifies that a valid request to `/vertex/generate` returns a 200 OK and correct structure.
2.  **`test_vertex_route_insufficient_credits`**: (Planned/Implicit) Verifies 402/403 when credits are low.
3.  **`test_byok_route_success`**: Verifies that a valid BYOK request proceeds when a custom key is present.
4.  **`test_byok_route_no_key`**: Critical security test. Verifies that a request to `/byok/generate` without a configured key returns `403 Forbidden` (verified fix).
5.  **`test_model_wrapper_error`**: Verifies that underlying model errors are caught and logged gracefully.

### Validation
Tests were executed locally using `pytest`. The `byok_routes.py` fix was validated by confirming the status code changed from 500 to 403 for missing keys.

---

## 6. Future Considerations

### Immediate Actions
-   **Deprecation Updates**: Replace usage of `datetime.utcnow()` with `datetime.now(datetime.timezone.utc)` to address Python warnings.

### Enhancements
-   **Frontend Integration**: Connect the new API endpoints to the chat interface.
-   **Granular Quotas**: Implement stricter rate limiting per user (Redis-based) to prevent abuse of the Vertex endpoints.
-   **Streaming Response Support**: While the wrapper supports streaming, the API endpoints currently return full responses. Expose streaming endpoints (Server-Sent Events) for better UX.
-   **Enhanced Error Feedback**: Provide more descriptive error messages to the client for specific model failures (e.g., safety filters).
