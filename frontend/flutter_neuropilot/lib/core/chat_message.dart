/// Represents a single message in the chat history.
///
/// This model is used to pass message data between the UI and the state management layer.
///
/// Implementation Details:
/// - Immutable data class.
/// - [role] typically matches standard LLM roles ('user', 'assistant', 'system').
/// - [time] defaults to `DateTime.now()` if not provided.
///
/// Design Decisions:
/// - Kept minimal to reduce overhead.
/// - Does not contain UI-specific logic (like "isSending"), which is handled by the state layer or UI wrappers.
///
/// Behavioral Specifications:
/// - [time] is automatically set to the current time upon creation if null.
class ChatMessage {
  /// The sender of the message (e.g., 'user', 'assistant').
  final String role; // 'user' | 'assistant' | 'system'

  /// The text content of the message.
  final String content;

  /// The timestamp when the message was created.
  final DateTime time;

  /// Optional metadata for rich UI rendering (e.g., calendar events).
  final Map<String, dynamic>? metadata;

  /// Creates a new [ChatMessage].
  ///
  /// If [time] is omitted, it defaults to the current time.
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? time,
    this.metadata,
  }) : time = time ?? DateTime.now();
}
