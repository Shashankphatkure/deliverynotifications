import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final supabase = Supabase.instance.client;

  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-notification',
        body: {
          'recipientId': recipientId,
          'title': title,
          'message': message,
          'type': type,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to send notification: ${response.data}');
      }

      print('Notification sent successfully: ${response.data}');
    } catch (e) {
      print('Error sending notification: $e');
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> getNotificationLogs() {
    return supabase
        .from('notification_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((item) => item as Map<String, dynamic>).toList());
  }
} 