import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    if (kIsWeb) return; // Don't send notifications from web

    try {
      await OneSignal.User.addTagWithKey("user_id", userId);
      
      await OneSignal.Notifications.postNotification(
        OSCreateNotification(
          playerIds: [userId],
          content: message,
          heading: title,
          additionalData: additionalData,
        ),
      );
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  static Future<String?> getDeviceId() async {
    if (kIsWeb) return null;
    
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (e) {
      print('Error getting device ID: $e');
      return null;
    }
  }
} 