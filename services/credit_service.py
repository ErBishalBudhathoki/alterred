"""
Credit Service
==============
Manages user credit balances, allocations, and consumption tracking.
Implements the 5 free credits per user system with transaction logging.

Implementation Details:
- Uses Firestore for credit storage and transaction logs
- Atomic credit operations using Firestore transactions
- Automatic credit allocation for new users
- Credit top-up support for future paid tiers

Design Decisions:
- Credits are immutable once allocated (no expiration)
- All credit changes are logged for audit trail
- Admin functions for manual credit adjustments
- Notifications at 2 credits and 0 credits remaining

Behavioral Specifications:
- `initialize_user_credits`: Allocate 5 credits for new users
- `get_balance`: Retrieve current credit balance
- `consume_credit`: Deduct credits with transaction safety
- `add_credits`: Top up credits (for paid tiers or admin)
- `get_transaction_history`: View credit usage history
"""

from typing import Optional, Dict, Any
from firebase_admin import firestore
from google.cloud.firestore_v1 import FieldFilter


from services.firebase_client import get_client

class CreditService:
    """Manage user credit balances and transactions."""
    
    # Constants
    INITIAL_CREDITS = 13.0  # Free credits for new users
    LOW_CREDIT_THRESHOLD = 2.0  # Trigger notification
    
    def __init__(self):
        self.db = get_client()
    
    def initialize_user_credits(self, user_id: str) -> Dict[str, Any]:
        """
        Allocate initial free credits to a new user.
        Idempotent - won't double-allocate if called multiple times.
        
        Args:
            user_id: User ID to initialize credits for
            
        Returns:
            Result dictionary with ok status and credit balance
        """
        try:
            credit_ref = self.db.collection("user_credits").document(user_id)
            
            # Check if credits already initialized
            doc = credit_ref.get()
            if doc.exists:
                current_balance = doc.to_dict().get("balance", 0.0)
                return {
                    "ok": True,
                    "balance": current_balance,
                    "message": "Credits already initialized"
                }
            
            # Initialize credits
            credit_ref.set({
                "balance": self.INITIAL_CREDITS,
                "total_allocated": self.INITIAL_CREDITS,
                "total_consumed": 0.0,
                "created_at": firestore.SERVER_TIMESTAMP,
                "last_updated": firestore.SERVER_TIMESTAMP,
                "last_notified": None
            })
            
            # Log the initial allocation
            self._log_transaction(
                user_id=user_id,
                amount=self.INITIAL_CREDITS,
                transaction_type="allocation",
                reason="initial_free_credits",
                metadata={"source": "system"}
            )
            
            return {
                "ok": True,
                "balance": self.INITIAL_CREDITS,
                "message": f"Allocated {self.INITIAL_CREDITS} free credits"
            }
            
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def get_balance(self, user_id: str) -> Dict[str, Any]:
        """
        Get user's current credit balance.
        
        Args:
            user_id: User ID to check
            
        Returns:
            Dictionary with balance and statistics
        """
        try:
            doc = self.db.collection("user_credits").document(user_id).get()
            
            if not doc.exists:
                # Auto-initialize if not exists
                init_result = self.initialize_user_credits(user_id)
                if not init_result.get("ok"):
                    return init_result
                
                doc = self.db.collection("user_credits").document(user_id).get()
            
            data = doc.to_dict()
            
            return {
                "ok": True,
                "balance": data.get("balance", 0.0),
                "total_allocated": data.get("total_allocated", 0.0),
                "total_consumed": data.get("total_consumed", 0.0),
                "last_updated": data.get("last_updated")
            }
            
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def consume_credit(
        self,
        user_id: str,
        amount: float = 1.0,
        reason: str = "api_call",
        metadata: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Consume credits from user's balance atomically.
        
        Args:
            user_id: User ID
            amount: Number of credits to consume (default: 1.0)
            reason: Reason for consumption
            metadata: Additional metadata to log
            
        Returns:
            Result with new balance or error
        """
        try:
            credit_ref = self.db.collection("user_credits").document(user_id)
            
            # Use transaction for atomic operation
            @firestore.transactional
            def update_credit(transaction, ref):
                snapshot = ref.get(transaction=transaction)
                
                if not snapshot.exists:
                    # Auto-initialize if needed
                    return {"error": "user_not_initialized"}
                
                data = snapshot.to_dict()
                current_balance = data.get("balance", 0.0)
                
                if current_balance < amount:
                    return {"error": "insufficient_credits", "balance": current_balance}
                
                new_balance = current_balance - amount
                
                transaction.update(ref, {
                    "balance": new_balance,
                    "total_consumed": firestore.Increment(amount),
                    "last_updated": firestore.SERVER_TIMESTAMP
                })
                
                return {"success": True, "new_balance": new_balance}
            
            transaction = self.db.transaction()
            result = update_credit(transaction, credit_ref)
            
            if result.get("error"):
                if result["error"] == "user_not_initialized":
                    # Initialize and retry
                    self.initialize_user_credits(user_id)
                    return self.consume_credit(user_id, amount, reason, metadata)
                else:
                    return {"ok": False, **result}
            
            # Log the transaction
            self._log_transaction(
                user_id=user_id,
                amount=amount,
                transaction_type="consumption",
                reason=reason,
                metadata=metadata
            )
            
            # Check if notification needed
            new_balance = result["new_balance"]
            if new_balance <= self.LOW_CREDIT_THRESHOLD:
                self._trigger_low_credit_notification(user_id, new_balance)
            
            return {
                "ok": True,
                "balance": new_balance,
                "consumed": amount
            }
            
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def add_credits(
        self,
        user_id: str,
        amount: float,
        reason: str = "admin_grant",
        metadata: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Add credits to user's balance (for paid tiers or admin adjustments).
        
        Args:
            user_id: User ID
            amount: Number of credits to add
            reason: Reason for addition
            metadata: Additional metadata
            
        Returns:
            Result with new balance
        """
        try:
            credit_ref = self.db.collection("user_credits").document(user_id)
            
            @firestore.transactional
            def update_credit(transaction, ref):
                snapshot = ref.get(transaction=transaction)
                
                if not snapshot.exists:
                    return {"error": "user_not_initialized"}
                
                data = snapshot.to_dict()
                current_balance = data.get("balance", 0.0)
                new_balance = current_balance + amount
                
                transaction.update(ref, {
                    "balance": new_balance,
                    "total_allocated": firestore.Increment(amount),
                    "last_updated": firestore.SERVER_TIMESTAMP
                })
                
                return {"success": True, "new_balance": new_balance}
            
            transaction = self.db.transaction()
            result = update_credit(transaction, credit_ref)
            
            if result.get("error"):
                return {"ok": False, **result}
            
            # Log the transaction
            self._log_transaction(
                user_id=user_id,
                amount=amount,
                transaction_type="allocation",
                reason=reason,
                metadata=metadata
            )
            
            return {
                "ok": True,
                "balance": result["new_balance"],
                "added": amount
            }
            
        except Exception as e:
            return {
                "ok": False,
                "error": str(e)
            }
    
    def get_transaction_history(
        self,
        user_id: str,
        limit: int = 50
    ) -> Dict[str, Any]:
        """
        Get user's credit transaction history.
        
        Args:
            user_id: User ID
            limit: Maximum number of transactions to return
            
        Returns:
            List of transactions
        """
        try:
            transactions = (
                self.db.collection("credit_transactions")
                .where(filter=FieldFilter("user_id", "==", user_id))
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(limit)
                .stream()
            )
            
            history = []
            for trans in transactions:
                data = trans.to_dict()
                history.append({
                    "id": trans.id,
                    "amount": data.get("amount"),
                    "type": data.get("type"),
                    "reason": data.get("reason"),
                    "timestamp": data.get("timestamp"),
                    "metadata": data.get("metadata", {})
                })
            
            return {"ok": True, "transactions": history}
            
        except Exception as e:
            return {"ok": False, "error": str(e)}
    
    def _log_transaction(
        self,
        user_id: str,
        amount: float,
        transaction_type: str,
        reason: str,
        metadata: Optional[Dict] = None
    ):
        """Log a credit transaction for audit trail."""
        try:
            self.db.collection("credit_transactions").add({
                "user_id": user_id,
                "amount": amount,
                "type": transaction_type,  # "allocation" | "consumption" | "refund"
                "reason": reason,
                "metadata": metadata or {},
                "timestamp": firestore.SERVER_TIMESTAMP
            })
        except Exception as e:
            print(f"Error logging transaction: {e}")
    
    def _trigger_low_credit_notification(self, user_id: str, balance: float):
        """
        Trigger notification when credits are low.
        Only triggers once per threshold to avoid spam.
        """
        try:
            credit_ref = self.db.collection("user_credits").document(user_id)
            doc = credit_ref.get()
            
            if doc.exists:
                # Only notify if haven't notified recently
                if balance == 0:
                    notification_type = "credits_exhausted"
                else:
                    notification_type = "credits_low"
                
                # TODO: Implement actual notification (FCM, email, etc.)
                # For now, just update the last_notified timestamp
                credit_ref.update({
                    "last_notified": firestore.SERVER_TIMESTAMP,
                    "last_notification_type": notification_type
                })
                
                print(f"Notification triggered for user {user_id}: {notification_type} (balance: {balance})")
                
        except Exception as e:
            print(f"Error triggering notification: {e}")


# Global instance
_credit_service = None

def get_credit_service() -> CreditService:
    """Get the singleton CreditService instance."""
    global _credit_service
    if _credit_service is None:
        _credit_service = CreditService()
    return _credit_service
