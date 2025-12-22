from services.compaction_service import maybe_auto_compact

async def auto_compact_callback(callback_context):
    """
    Callback function executed after the agent processes a request.
    Triggers the compaction service to summarize and optimize session memory.
    Args:
        callback_context: Context object provided by the ADK runner.
    """
    try:
        user_id = callback_context._invocation_context.user_id
        app_name = callback_context._invocation_context.app_name
        session = callback_context._invocation_context.session
        maybe_auto_compact(user_id, app_name, session.id)
    except Exception:
        pass
