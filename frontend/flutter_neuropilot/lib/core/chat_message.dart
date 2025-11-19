class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime time;
  ChatMessage({required this.role, required this.content, DateTime? time}) : time = time ?? DateTime.now();
}