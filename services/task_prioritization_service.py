"""
Task Prioritization Service
===========================
Provides intelligent task prioritization for ADHD users to help overcome decision paralysis.

Implementation Details:
- Filters tasks to exclude completed, cancelled, or blocked tasks
- Uses schedule_tasks algorithm with energy and deadline weights
- Integrates with Google Calendar for conflict detection (optional)
- Returns exactly 3 prioritized tasks with scores and reasoning
- Persistent file-based caching for offline use

Design Decisions:
- Graceful fallback when calendar integration fails
- LLM-powered reasoning for task selection
- File-based caching for offline resilience
- Cache invalidation based on task state changes
"""
import os
import json
import logging
import hashlib
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict, field
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class PrioritizedTask:
    """A task with prioritization metadata."""
    id: str
    title: str
    description: Optional[str]
    due_date: Optional[str]
    priority: str
    status: str
    effort: str
    priority_score: float
    priority_reasoning: str
    is_recommended: bool
    estimated_duration_minutes: int
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "PrioritizedTask":
        """Create from dictionary."""
        return cls(**data)


@dataclass
class PrioritizedTasksResponse:
    """Response containing prioritized tasks."""
    tasks: List[PrioritizedTask]
    reasoning: str
    original_task_count: int
    timestamp: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "tasks": [t.to_dict() for t in self.tasks],
            "reasoning": self.reasoning,
            "original_task_count": self.original_task_count,
            "timestamp": self.timestamp,
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "PrioritizedTasksResponse":
        """Create from dictionary."""
        tasks = [PrioritizedTask.from_dict(t) for t in data.get("tasks", [])]
        return cls(
            tasks=tasks,
            reasoning=data.get("reasoning", ""),
            original_task_count=data.get("original_task_count", 0),
            timestamp=data.get("timestamp", ""),
        )


@dataclass
class CacheMetadata:
    """Metadata for cached prioritization."""
    user_id: str
    cached_at: str
    task_state_hash: str
    energy_level: int
    is_valid: bool = True


class PrioritizationCache:
    """
    File-based cache for task prioritization responses.
    
    Provides offline resilience by persisting the last successful prioritization
    and validating cache consistency against current task state.
    """
    
    DEFAULT_CACHE_DIR = ".cache/task_prioritization"
    CACHE_TTL_HOURS = 24  # Cache expires after 24 hours
    
    def __init__(self, user_id: str, cache_dir: Optional[str] = None):
        self.user_id = user_id
        self.cache_dir = Path(cache_dir or os.getenv("TASK_CACHE_DIR", self.DEFAULT_CACHE_DIR))
        self._ensure_cache_dir()
    
    def _ensure_cache_dir(self) -> None:
        """Ensure cache directory exists."""
        user_cache_dir = self.cache_dir / self.user_id
        user_cache_dir.mkdir(parents=True, exist_ok=True)
    
    def _get_cache_path(self) -> Path:
        """Get path to user's cache file."""
        return self.cache_dir / self.user_id / "prioritization_cache.json"
    
    def _get_metadata_path(self) -> Path:
        """Get path to user's cache metadata file."""
        return self.cache_dir / self.user_id / "cache_metadata.json"
    
    @staticmethod
    def compute_task_state_hash(tasks: List[Dict[str, Any]]) -> str:
        """
        Compute a hash of the current task state for cache invalidation.
        
        The hash is based on task IDs, statuses, and priorities to detect
        when the underlying task data has changed significantly.
        """
        if not tasks:
            return "empty"
        
        # Sort tasks by ID for consistent hashing
        sorted_tasks = sorted(tasks, key=lambda t: t.get("id", ""))
        
        # Create a string representation of relevant task state
        state_parts = []
        for task in sorted_tasks:
            state_parts.append(
                f"{task.get('id', '')}:{task.get('status', '')}:{task.get('priority', '')}"
            )
        
        state_string = "|".join(state_parts)
        return hashlib.md5(state_string.encode()).hexdigest()[:16]
    
    def save(
        self, 
        response: PrioritizedTasksResponse, 
        tasks: List[Dict[str, Any]],
        energy_level: int
    ) -> bool:
        """
        Save prioritization response to cache.
        
        Args:
            response: The prioritization response to cache
            tasks: Current task list for state hash computation
            energy_level: Energy level used for this prioritization
            
        Returns:
            True if save was successful, False otherwise
        """
        try:
            cache_path = self._get_cache_path()
            metadata_path = self._get_metadata_path()
            
            # Save response data
            cache_data = response.to_dict()
            cache_path.write_text(json.dumps(cache_data, indent=2))
            
            # Save metadata
            metadata = CacheMetadata(
                user_id=self.user_id,
                cached_at=datetime.now().isoformat(),
                task_state_hash=self.compute_task_state_hash(tasks),
                energy_level=energy_level,
                is_valid=True,
            )
            metadata_path.write_text(json.dumps(asdict(metadata), indent=2))
            
            logger.info(f"Cached prioritization for user {self.user_id}")
            return True
            
        except Exception as e:
            logger.warning(f"Failed to save prioritization cache: {e}")
            return False
    
    def load(self) -> Optional[PrioritizedTasksResponse]:
        """
        Load cached prioritization response.
        
        Returns:
            Cached response if available and valid, None otherwise
        """
        try:
            cache_path = self._get_cache_path()
            
            if not cache_path.exists():
                logger.debug(f"No cache file found for user {self.user_id}")
                return None
            
            cache_data = json.loads(cache_path.read_text())
            response = PrioritizedTasksResponse.from_dict(cache_data)
            
            logger.info(f"Loaded cached prioritization for user {self.user_id}")
            return response
            
        except Exception as e:
            logger.warning(f"Failed to load prioritization cache: {e}")
            return None
    
    def load_metadata(self) -> Optional[CacheMetadata]:
        """Load cache metadata."""
        try:
            metadata_path = self._get_metadata_path()
            
            if not metadata_path.exists():
                return None
            
            data = json.loads(metadata_path.read_text())
            return CacheMetadata(**data)
            
        except Exception as e:
            logger.warning(f"Failed to load cache metadata: {e}")
            return None
    
    def is_valid(self, current_tasks: List[Dict[str, Any]]) -> bool:
        """
        Check if cached data is still valid.
        
        Cache is considered invalid if:
        - No cache exists
        - Cache is older than TTL
        - Task state has changed significantly
        
        Args:
            current_tasks: Current task list to compare against cached state
            
        Returns:
            True if cache is valid, False otherwise
        """
        metadata = self.load_metadata()
        
        if not metadata:
            return False
        
        if not metadata.is_valid:
            return False
        
        # Check TTL
        try:
            cached_at = datetime.fromisoformat(metadata.cached_at)
            age_hours = (datetime.now() - cached_at).total_seconds() / 3600
            if age_hours > self.CACHE_TTL_HOURS:
                logger.debug(f"Cache expired (age: {age_hours:.1f} hours)")
                return False
        except (ValueError, TypeError):
            return False
        
        # Check task state consistency
        current_hash = self.compute_task_state_hash(current_tasks)
        if current_hash != metadata.task_state_hash:
            logger.debug(f"Task state changed (cached: {metadata.task_state_hash}, current: {current_hash})")
            return False
        
        return True
    
    def invalidate(self) -> None:
        """Mark cache as invalid."""
        try:
            metadata = self.load_metadata()
            if metadata:
                metadata.is_valid = False
                metadata_path = self._get_metadata_path()
                metadata_path.write_text(json.dumps(asdict(metadata), indent=2))
                logger.info(f"Invalidated cache for user {self.user_id}")
        except Exception as e:
            logger.warning(f"Failed to invalidate cache: {e}")
    
    def clear(self) -> None:
        """Remove all cached data for this user."""
        try:
            cache_path = self._get_cache_path()
            metadata_path = self._get_metadata_path()
            
            if cache_path.exists():
                cache_path.unlink()
            if metadata_path.exists():
                metadata_path.unlink()
                
            logger.info(f"Cleared cache for user {self.user_id}")
        except Exception as e:
            logger.warning(f"Failed to clear cache: {e}")


class TaskFilterService:
    """Filters and scores tasks for prioritization."""
    
    ELIGIBLE_STATUSES = {"pending", "in_progress"}
    BLOCKED_STATUSES = {"completed", "cancelled", "blocked"}
    
    PRIORITY_WEIGHTS = {
        "critical": 4,
        "high": 3,
        "medium": 2,
        "low": 1
    }
    
    EFFORT_WEIGHTS = {
        "low": 3,    # Low effort = higher score (easier to start)
        "medium": 2,
        "high": 1
    }
    
    @classmethod
    def filter_eligible_tasks(cls, tasks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Filter tasks to only include eligible ones.
        
        Args:
            tasks: List of task dictionaries
            
        Returns:
            List of eligible tasks (pending or in_progress, not blocked)
        """
        eligible = []
        for task in tasks:
            status = (task.get("status") or "pending").lower()
            if status in cls.ELIGIBLE_STATUSES and status not in cls.BLOCKED_STATUSES:
                eligible.append(task)
        return eligible
    
    @classmethod
    def calculate_priority_scores(
        cls, 
        tasks: List[Dict[str, Any]], 
        energy: int,
        calendar_events: Optional[List[Dict[str, Any]]] = None
    ) -> List[Dict[str, Any]]:
        """
        Calculate priority scores for tasks based on multiple factors.
        
        Args:
            tasks: List of task dictionaries
            energy: User's current energy level (1-10)
            calendar_events: Optional list of calendar events for conflict detection
            
        Returns:
            List of tasks with priority_score added
        """
        scored_tasks = []
        now = datetime.now()
        
        for task in tasks:
            score = 0.0
            
            # Priority weight (0-4 points)
            priority = (task.get("priority") or "medium").lower()
            score += cls.PRIORITY_WEIGHTS.get(priority, 2)
            
            # Effort vs Energy match (0-3 points)
            effort = (task.get("effort") or "medium").lower()
            effort_score = cls.EFFORT_WEIGHTS.get(effort, 2)
            
            # Match effort to energy: low energy prefers low effort tasks
            if energy <= 3:
                # Low energy: prefer low effort tasks
                if effort == "low":
                    score += 3
                elif effort == "medium":
                    score += 1
            elif energy <= 6:
                # Medium energy: prefer medium effort
                if effort == "medium":
                    score += 3
                else:
                    score += 1
            else:
                # High energy: can handle any effort
                score += effort_score
            
            # Due date urgency (0-5 points)
            due_date_str = task.get("dueDate") or task.get("due_date")
            if due_date_str:
                try:
                    due_date = datetime.fromisoformat(due_date_str.replace("Z", "+00:00"))
                    if due_date.tzinfo:
                        due_date = due_date.replace(tzinfo=None)
                    
                    hours_until_due = (due_date - now).total_seconds() / 3600
                    
                    if hours_until_due < 0:
                        score += 5  # Overdue - highest urgency
                    elif hours_until_due < 4:
                        score += 4  # Due within 4 hours
                    elif hours_until_due < 24:
                        score += 3  # Due today
                    elif hours_until_due < 72:
                        score += 2  # Due within 3 days
                    else:
                        score += 1  # Due later
                except (ValueError, TypeError):
                    score += 1  # Default if date parsing fails
            else:
                score += 1  # No due date - lower urgency
            
            # Calendar conflict penalty (if events provided)
            if calendar_events:
                has_conflict = cls._check_calendar_conflict(task, calendar_events)
                if has_conflict:
                    score -= 2  # Penalize tasks that conflict with calendar
            
            task_with_score = task.copy()
            task_with_score["priority_score"] = round(score, 2)
            scored_tasks.append(task_with_score)
        
        # Sort by score descending
        scored_tasks.sort(key=lambda t: t["priority_score"], reverse=True)
        return scored_tasks
    
    @classmethod
    def _check_calendar_conflict(
        cls, 
        task: Dict[str, Any], 
        events: List[Dict[str, Any]]
    ) -> bool:
        """Check if a task conflicts with calendar events in the next 2 hours."""
        now = datetime.now()
        window_end = now + timedelta(hours=2)
        
        for event in events:
            start_str = event.get("start", {}).get("dateTime") or event.get("start", {}).get("date")
            end_str = event.get("end", {}).get("dateTime") or event.get("end", {}).get("date")
            
            if not start_str:
                continue
                
            try:
                start = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
                if start.tzinfo:
                    start = start.replace(tzinfo=None)
                
                # Check if event is within the next 2 hours
                if now <= start <= window_end:
                    return True
            except (ValueError, TypeError):
                continue
        
        return False


class TaskPrioritizationService:
    """Main service for task prioritization."""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.filter_service = TaskFilterService()
        self._memory_cache: Optional[PrioritizedTasksResponse] = None
        self._memory_cache_timestamp: Optional[datetime] = None
        self._memory_cache_ttl = timedelta(minutes=5)
        self._persistent_cache = PrioritizationCache(user_id)
        self._network_available: bool = True
    
    async def get_prioritized_tasks(
        self,
        limit: int = 3,
        include_calendar: bool = True,
        energy: Optional[int] = None,
        use_cache_fallback: bool = True
    ) -> PrioritizedTasksResponse:
        """
        Get prioritized tasks for the user.
        
        Args:
            limit: Maximum number of tasks to return (default 3)
            include_calendar: Whether to include calendar data for conflict detection
            energy: User's current energy level (1-10), defaults to 5
            use_cache_fallback: Whether to use cached data if network fails
            
        Returns:
            PrioritizedTasksResponse with top tasks
        """
        energy = energy or 5
        
        # Try to fetch fresh data
        try:
            response = await self._fetch_and_prioritize(limit, include_calendar, energy)
            self._network_available = True
            return response
        except Exception as e:
            logger.warning(f"Failed to fetch fresh prioritization: {e}")
            self._network_available = False
            
            if use_cache_fallback:
                cached = await self._get_cached_fallback()
                if cached:
                    logger.info("Using cached prioritization due to network failure")
                    return cached
            
            # Return empty response if no cache available
            return PrioritizedTasksResponse(
                tasks=[],
                reasoning="Unable to fetch tasks. Please check your internet connection and try again.",
                original_task_count=0,
                timestamp=datetime.now().isoformat()
            )
    
    async def _fetch_and_prioritize(
        self,
        limit: int,
        include_calendar: bool,
        energy: int
    ) -> PrioritizedTasksResponse:
        """Fetch tasks and perform prioritization."""
        # Fetch user's tasks from Firestore
        tasks = await self._fetch_user_tasks()
        original_count = len(tasks)
        
        if not tasks:
            return PrioritizedTasksResponse(
                tasks=[],
                reasoning="No tasks found. Consider creating some tasks or taking a well-deserved break!",
                original_task_count=0,
                timestamp=datetime.now().isoformat()
            )
        
        # Filter eligible tasks
        eligible_tasks = self.filter_service.filter_eligible_tasks(tasks)
        
        if not eligible_tasks:
            return PrioritizedTasksResponse(
                tasks=[],
                reasoning="All your tasks are completed or blocked. Great job! Time to add new tasks or enjoy a break.",
                original_task_count=original_count,
                timestamp=datetime.now().isoformat()
            )
        
        # Get calendar events if requested
        calendar_events = None
        if include_calendar:
            calendar_events = await self._fetch_calendar_events()
        
        # Calculate priority scores
        scored_tasks = self.filter_service.calculate_priority_scores(
            eligible_tasks, 
            energy, 
            calendar_events
        )
        
        # Take top N tasks
        top_tasks = scored_tasks[:limit]
        
        # Generate reasoning using LLM
        reasoning = await self._generate_reasoning(top_tasks, energy, original_count)
        
        # Convert to PrioritizedTask objects
        prioritized_tasks = []
        for i, task in enumerate(top_tasks):
            prioritized_task = PrioritizedTask(
                id=task.get("id", ""),
                title=task.get("title", "Untitled"),
                description=task.get("description"),
                due_date=task.get("dueDate") or task.get("due_date"),
                priority=task.get("priority", "medium"),
                status=task.get("status", "pending"),
                effort=task.get("effort", "medium"),
                priority_score=task.get("priority_score", 0),
                priority_reasoning=self._get_task_reasoning(task, energy),
                is_recommended=(i == 0),  # First task is recommended
                estimated_duration_minutes=self._estimate_duration(task)
            )
            prioritized_tasks.append(prioritized_task)
        
        response = PrioritizedTasksResponse(
            tasks=prioritized_tasks,
            reasoning=reasoning,
            original_task_count=original_count,
            timestamp=datetime.now().isoformat()
        )
        
        # Update memory cache
        self._memory_cache = response
        self._memory_cache_timestamp = datetime.now()
        
        # Persist to file cache for offline use
        self._persistent_cache.save(response, tasks, energy)
        
        return response
    
    async def _get_cached_fallback(self) -> Optional[PrioritizedTasksResponse]:
        """
        Get cached prioritization as fallback.
        
        First checks memory cache, then persistent file cache.
        """
        # Try memory cache first
        memory_cached = self.get_cached_response()
        if memory_cached:
            return memory_cached
        
        # Try persistent cache
        return self._persistent_cache.load()
    
    async def get_prioritized_tasks_with_cache_status(
        self,
        limit: int = 3,
        include_calendar: bool = True,
        energy: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Get prioritized tasks with cache status information.
        
        Returns additional metadata about whether the response came from cache.
        """
        energy = energy or 5
        
        try:
            response = await self._fetch_and_prioritize(limit, include_calendar, energy)
            return {
                "response": response,
                "from_cache": False,
                "cache_valid": True,
                "network_available": True,
            }
        except Exception as e:
            logger.warning(f"Network error, attempting cache fallback: {e}")
            
            cached = await self._get_cached_fallback()
            if cached:
                return {
                    "response": cached,
                    "from_cache": True,
                    "cache_valid": True,
                    "network_available": False,
                }
            
            return {
                "response": None,
                "from_cache": False,
                "cache_valid": False,
                "network_available": False,
            }
    
    async def select_task(
        self,
        task_id: str,
        selection_method: str = "manual"
    ) -> Dict[str, Any]:
        """
        Record task selection and prepare for focus session.
        
        Args:
            task_id: ID of the selected task
            selection_method: 'manual' or 'auto'
            
        Returns:
            Task selection response with focus session info
        """
        from services.firebase_client import get_client
        
        db = get_client()
        if not db:
            return {"ok": False, "error": "Database unavailable"}
        
        # Get the task
        task_ref = db.collection("users").document(self.user_id).collection("tasks").document(task_id)
        task_doc = task_ref.get()
        
        if not task_doc.exists:
            return {"ok": False, "error": "Task not found"}
        
        task_data = task_doc.to_dict()
        task_data["id"] = task_id
        
        # Update task status to in_progress
        task_ref.update({"status": "in_progress"})
        
        # Log the selection event
        await self._log_selection_event(task_id, selection_method)
        
        return {
            "ok": True,
            "task": task_data,
            "selection_method": selection_method,
            "message": f"Starting focus session for: {task_data.get('title', 'Untitled')}",
            "ui_mode": "focus_session"
        }
    
    def get_cached_response(self) -> Optional[PrioritizedTasksResponse]:
        """Get cached prioritization if still valid (memory cache)."""
        if self._memory_cache and self._memory_cache_timestamp:
            if datetime.now() - self._memory_cache_timestamp < self._memory_cache_ttl:
                return self._memory_cache
        return None
    
    def get_persistent_cached_response(self) -> Optional[PrioritizedTasksResponse]:
        """Get persistent file-based cached response."""
        return self._persistent_cache.load()
    
    async def is_cache_consistent(self) -> bool:
        """
        Check if the persistent cache is consistent with current task state.
        
        Returns:
            True if cache is valid and consistent, False otherwise
        """
        try:
            tasks = await self._fetch_user_tasks()
            return self._persistent_cache.is_valid(tasks)
        except Exception as e:
            logger.warning(f"Failed to check cache consistency: {e}")
            return False
    
    def invalidate_cache(self) -> None:
        """Invalidate both memory and persistent caches."""
        self._memory_cache = None
        self._memory_cache_timestamp = None
        self._persistent_cache.invalidate()
    
    def is_network_available(self) -> bool:
        """Check if network was available on last request."""
        return self._network_available
    
    async def _fetch_user_tasks(self) -> List[Dict[str, Any]]:
        """Fetch tasks from Firestore."""
        from services.firebase_client import get_client
        
        db = get_client()
        if not db:
            logger.error("Database unavailable for task fetch")
            return []
        
        try:
            tasks_ref = db.collection("users").document(self.user_id).collection("tasks")
            docs = tasks_ref.stream()
            
            tasks = []
            for doc in docs:
                data = doc.to_dict()
                data["id"] = doc.id
                tasks.append(data)
            
            return tasks
        except Exception as e:
            logger.error(f"Failed to fetch tasks: {e}")
            return []
    
    async def _fetch_calendar_events(self) -> Optional[List[Dict[str, Any]]]:
        """Fetch today's calendar events. Returns None on failure."""
        try:
            from services.calendar_mcp import list_events_today
            
            result = list_events_today(user_id=self.user_id)
            if result.get("ok") and result.get("events"):
                return result["events"]
            return None
        except Exception as e:
            logger.warning(f"Calendar integration failed (graceful fallback): {e}")
            return None
    
    async def _generate_reasoning(
        self, 
        tasks: List[Dict[str, Any]], 
        energy: int,
        original_count: int
    ) -> str:
        """Generate human-readable reasoning for the prioritization."""
        if not tasks:
            return "No eligible tasks to prioritize."
        
        try:
            from agents.adk_model import get_adk_model
            
            task_summaries = [
                f"- {t.get('title')} (priority: {t.get('priority')}, effort: {t.get('effort')}, score: {t.get('priority_score')})"
                for t in tasks
            ]
            
            prompt = (
                f"You are an ADHD-friendly task coach. The user has {original_count} tasks total.\n"
                f"Their current energy level is {energy}/10.\n"
                f"I've selected these {len(tasks)} tasks as the best options:\n"
                + "\n".join(task_summaries) + "\n\n"
                "Write a brief (2-3 sentences), supportive explanation of why these tasks were chosen. "
                "Focus on being encouraging and reducing decision anxiety. "
                "Mention the energy-effort match if relevant."
            )
            
            model = get_adk_model()
            resp = model.api_client.models.generate_content(
                model=model.model,
                contents=prompt
            )
            
            if resp and resp.text:
                return resp.text.strip()
        except Exception as e:
            logger.warning(f"LLM reasoning generation failed: {e}")
        
        # Fallback reasoning
        top_task = tasks[0] if tasks else {}
        return (
            f"I've narrowed down your {original_count} tasks to {len(tasks)} manageable options. "
            f"Based on your energy level ({energy}/10), '{top_task.get('title', 'the first task')}' "
            f"is my top recommendation - it matches your current capacity."
        )
    
    def _get_task_reasoning(self, task: Dict[str, Any], energy: int) -> str:
        """Generate brief reasoning for a specific task's ranking."""
        reasons = []
        
        priority = (task.get("priority") or "medium").lower()
        if priority in ["critical", "high"]:
            reasons.append("high priority")
        
        effort = (task.get("effort") or "medium").lower()
        if energy <= 3 and effort == "low":
            reasons.append("matches your low energy")
        elif energy >= 7 and effort == "high":
            reasons.append("good for your high energy")
        
        due_date_str = task.get("dueDate") or task.get("due_date")
        if due_date_str:
            try:
                due_date = datetime.fromisoformat(due_date_str.replace("Z", "+00:00"))
                if due_date.tzinfo:
                    due_date = due_date.replace(tzinfo=None)
                hours_until = (due_date - datetime.now()).total_seconds() / 3600
                if hours_until < 0:
                    reasons.append("overdue")
                elif hours_until < 24:
                    reasons.append("due today")
            except (ValueError, TypeError):
                pass
        
        if not reasons:
            reasons.append("good balance of priority and effort")
        
        return ", ".join(reasons).capitalize()
    
    def _estimate_duration(self, task: Dict[str, Any]) -> int:
        """Estimate task duration in minutes based on effort."""
        effort = (task.get("effort") or "medium").lower()
        estimates = {
            "low": 15,
            "medium": 30,
            "high": 60
        }
        return estimates.get(effort, 30)
    
    async def _log_selection_event(self, task_id: str, selection_method: str) -> None:
        """Log task selection event for analytics."""
        from services.firebase_client import get_client
        
        db = get_client()
        if not db:
            return
        
        try:
            events_ref = db.collection("users").document(self.user_id).collection("task_events")
            events_ref.add({
                "type": "task_selected",
                "task_id": task_id,
                "selection_method": selection_method,
                "timestamp": datetime.now().isoformat()
            })
        except Exception as e:
            logger.warning(f"Failed to log selection event: {e}")
