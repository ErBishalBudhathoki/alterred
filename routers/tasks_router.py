from fastapi import APIRouter, Depends, HTTPException, Body, Request
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from datetime import datetime
from dataclasses import asdict
from services.auth import get_user_id_from_request
from services.firebase_client import get_client
from services.task_prioritization_service import TaskPrioritizationService
from google.cloud.firestore import Query
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tasks", tags=["tasks"])

class Task(BaseModel):
    id: Optional[str] = None
    title: str
    description: Optional[str] = None
    dueDate: Optional[str] = None
    priority: Optional[str] = "medium"
    status: Optional[str] = "pending"
    effort: Optional[str] = "medium"
    createdAt: Optional[str] = None


class TaskSelectionRequest(BaseModel):
    """Request body for task selection."""
    task_id: str
    selection_method: str = "manual"  # 'manual' or 'auto'
    time_to_select_seconds: Optional[int] = None

@router.get("/")
async def list_tasks(request: Request):
    """
    List all tasks for the authenticated user, ordered by due date.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    db = get_client()
    if not db:
        raise HTTPException(status_code=500, detail="Database unavailable")
        
    tasks_ref = db.collection("users").document(user_id).collection("tasks")
    # Order by dueDate ascending, nulls last (if possible, otherwise handle in client)
    docs = tasks_ref.order_by("dueDate", direction=Query.ASCENDING).stream()
    
    tasks = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        tasks.append(data)
        
    return {"tasks": tasks}

@router.post("/")
async def create_task(request: Request, task: Task):
    """
    Create a new task for the authenticated user.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    db = get_client()
    if not db:
        raise HTTPException(status_code=500, detail="Database unavailable")
        
    tasks_ref = db.collection("users").document(user_id).collection("tasks")
    
    task_data = task.dict(exclude={"id"})
    if not task_data.get("createdAt"):
        task_data["createdAt"] = datetime.now().isoformat()
        
    _, doc_ref = tasks_ref.add(task_data)
    
    return {"id": doc_ref.id, **task_data}

@router.put("/{task_id}")
async def update_task(request: Request, task_id: str, task: Task):
    """
    Update an existing task.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    db = get_client()
    if not db:
        raise HTTPException(status_code=500, detail="Database unavailable")
        
    task_ref = db.collection("users").document(user_id).collection("tasks").document(task_id)
    
    # Check if exists
    if not task_ref.get().exists:
        raise HTTPException(status_code=404, detail="Task not found")
        
    task_data = task.dict(exclude={"id"}, exclude_unset=True)
    task_ref.update(task_data)
    
    return {"id": task_id, **task_data}

@router.delete("/{task_id}")
async def delete_task(request: Request, task_id: str):
    """
    Delete a task.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    db = get_client()
    if not db:
        raise HTTPException(status_code=500, detail="Database unavailable")
        
    task_ref = db.collection("users").document(user_id).collection("tasks").document(task_id)
    task_ref.delete()
    
    return {"ok": True}


@router.get("/prioritized")
async def get_prioritized_tasks(
    request: Request,
    limit: int = 3,
    include_calendar: bool = True,
    energy: Optional[int] = None
):
    """
    Get prioritized tasks for the user.
    
    Returns exactly 3 (or specified limit) tasks that are:
    - Filtered to exclude completed, cancelled, or blocked tasks
    - Scored based on priority, effort, due date, and energy level
    - Optionally considers calendar conflicts
    
    Args:
        limit: Maximum number of tasks to return (default 3)
        include_calendar: Whether to include calendar data for conflict detection
        energy: User's current energy level (1-10), defaults to 5
        
    Returns:
        PrioritizedTasksResponse with top tasks, reasoning, and metadata
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    # Validate energy level
    if energy is not None and (energy < 1 or energy > 10):
        raise HTTPException(status_code=400, detail="Energy must be between 1 and 10")
    
    try:
        service = TaskPrioritizationService(user_id)
        response = await service.get_prioritized_tasks(
            limit=limit,
            include_calendar=include_calendar,
            energy=energy
        )
        
        # Convert dataclass to dict for JSON response
        return {
            "ok": True,
            "tasks": [asdict(task) for task in response.tasks],
            "reasoning": response.reasoning,
            "original_task_count": response.original_task_count,
            "timestamp": response.timestamp,
            "ui_mode": "task_prioritization"
        }
    except Exception as e:
        logger.error(f"Task prioritization failed for user {user_id}: {e}")
        raise HTTPException(
            status_code=500, 
            detail={
                "error": "prioritization_failed",
                "message": "Unable to prioritize tasks. Please try again.",
                "suggestion": "Check your internet connection or try refreshing."
            }
        )


@router.post("/select")
async def select_task(request: Request, selection: TaskSelectionRequest):
    """
    Record task selection and start focus session.
    
    This endpoint is called when a user selects a task from the prioritization widget,
    either manually or via auto-selection when the countdown expires.
    
    Args:
        selection: TaskSelectionRequest with task_id and selection_method
        
    Returns:
        Task selection response with focus session info
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    if not selection.task_id:
        raise HTTPException(status_code=400, detail="task_id is required")
    
    if selection.selection_method not in ["manual", "auto"]:
        raise HTTPException(status_code=400, detail="selection_method must be 'manual' or 'auto'")
    
    try:
        service = TaskPrioritizationService(user_id)
        result = await service.select_task(
            task_id=selection.task_id,
            selection_method=selection.selection_method
        )
        
        if not result.get("ok"):
            raise HTTPException(status_code=404, detail=result.get("error", "Task not found"))
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Task selection failed for user {user_id}: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "error": "selection_failed",
                "message": "Unable to select task. Please try again."
            }
        )


@router.get("/prioritized/cached")
async def get_cached_prioritization(request: Request):
    """
    Get cached prioritization if available.
    
    This endpoint is useful for offline scenarios or quick UI updates
    without making a full prioritization request.
    
    Returns:
        Cached prioritization response or 404 if no cache available
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    service = TaskPrioritizationService(user_id)
    
    # Try memory cache first, then persistent cache
    cached = service.get_cached_response()
    cache_source = "memory"
    
    if not cached:
        cached = service.get_persistent_cached_response()
        cache_source = "persistent"
    
    if not cached:
        raise HTTPException(
            status_code=404, 
            detail={
                "error": "no_cache",
                "message": "No cached prioritization available. Request fresh prioritization."
            }
        )
    
    return {
        "ok": True,
        "tasks": [asdict(task) for task in cached.tasks],
        "reasoning": cached.reasoning,
        "original_task_count": cached.original_task_count,
        "timestamp": cached.timestamp,
        "cached": True,
        "cache_source": cache_source,
        "ui_mode": "task_prioritization"
    }


@router.get("/prioritized/cache-status")
async def get_cache_status(request: Request):
    """
    Get the status of the prioritization cache.
    
    Returns information about cache validity and consistency.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    service = TaskPrioritizationService(user_id)
    
    has_memory_cache = service.get_cached_response() is not None
    has_persistent_cache = service.get_persistent_cached_response() is not None
    
    # Check cache consistency (this may fail if network is unavailable)
    cache_consistent = False
    try:
        cache_consistent = await service.is_cache_consistent()
    except Exception:
        pass
    
    return {
        "ok": True,
        "has_memory_cache": has_memory_cache,
        "has_persistent_cache": has_persistent_cache,
        "cache_consistent": cache_consistent,
        "network_available": service.is_network_available()
    }


@router.post("/prioritized/invalidate-cache")
async def invalidate_cache(request: Request):
    """
    Invalidate the prioritization cache.
    
    This should be called when tasks are modified to ensure
    the next prioritization request fetches fresh data.
    """
    user_id = get_user_id_from_request(request)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    service = TaskPrioritizationService(user_id)
    service.invalidate_cache()
    
    return {
        "ok": True,
        "message": "Cache invalidated successfully"
    }
