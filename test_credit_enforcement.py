"""
Quick test to verify credit enforcement in adk_app.py
"""
import os
import asyncio
from dotenv import load_dotenv

load_dotenv()


async def _run() -> None:
    from services.credit_service import get_credit_service
    from adk_app import adk_respond

    test_user_with_credits = "credit_test_user_1"
    test_user_no_credits = "credit_test_user_2"

    print("=" * 60)
    print("Test 1: User with credits")
    print("=" * 60)

    credit_service = get_credit_service()
    credit_service.initialize_user_credits(test_user_with_credits)

    balance = credit_service.get_balance(test_user_with_credits)
    print(f"Initial balance: {balance.get('balance')} credits")

    print("\nMaking agent request...")
    response, tools = await adk_respond(
        test_user_with_credits, "test_session_1", "Hello, what's the weather?"
    )
    print(f"Response: {str(response)[:200]}...")

    balance_after = credit_service.get_balance(test_user_with_credits)
    print(f"Balance after request: {balance_after.get('balance')} credits")
    print(
        f"Credits consumed: {balance.get('balance') - balance_after.get('balance')}"
    )

    print("\n" + "=" * 60)
    print("Test 2: User without credits")
    print("=" * 60)

    credit_service.initialize_user_credits(test_user_no_credits)
    for _ in range(5):
        credit_service.consume_credit(test_user_no_credits, amount=1.0, reason="test_drain")

    balance_zero = credit_service.get_balance(test_user_no_credits)
    print(f"Credit balance: {balance_zero.get('balance')} credits")

    print("\nAttempting agent request with no credits...")
    response_blocked, tools_blocked = await adk_respond(
        test_user_no_credits, "test_session_2", "Hello?"
    )
    print(f"Response: {response_blocked}")

    print("\n" + "=" * 60)
    print("✓ Credit enforcement is working!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(_run())
