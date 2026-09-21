// lib/services/chat_exceptions.dart

/// Thrown when the chat is unavailable because there's no
/// CONFIRMED connection between the student and tutor.
class ChatUnavailableException implements Exception {
  final String message;
  ChatUnavailableException([this.message = 'Chat unavailable']);
  @override
  String toString() => message;
}

/// Thrown when the user isn't part of the chat room
/// (permission denied — someone else's conversation).
class ChatForbiddenException implements Exception {
  final String message;
  ChatForbiddenException([this.message = 'Chat forbidden']);
  @override
  String toString() => message;
}