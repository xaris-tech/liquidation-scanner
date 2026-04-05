import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - navigate to appropriate screen
  }

  static Future<void> showReceiptVerifiedNotification({
    required String vendor,
    required double amount,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'receipt_verified',
      'Receipt Verified',
      channelDescription: 'Notifications when receipts are verified',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Receipt Verified',
      '$vendor - ₱${amount.toStringAsFixed(2)} has been verified',
      details,
    );
  }

  static Future<void> showReceiptRejectedNotification({
    required String vendor,
    required double amount,
    String? reason,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'receipt_rejected',
      'Receipt Rejected',
      channelDescription: 'Notifications when receipts are rejected',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Receipt Rejected',
      '$vendor - ₱${amount.toStringAsFixed(2)} was rejected${reason != null ? ": $reason" : ""}',
      details,
    );
  }

  static Future<void> showNewReceiptNotification({
    required String vendor,
    required double amount,
    required String projectName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'new_receipt',
      'New Receipt',
      channelDescription: 'Notifications for new receipt uploads',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New Receipt Uploaded',
      '$vendor - ₱${amount.toStringAsFixed(2)} added to $projectName',
      details,
    );
  }

  static Future<void> showPendingAuditNotification({required int count}) async {
    const androidDetails = AndroidNotificationDetails(
      'pending_audit',
      'Pending Audits',
      channelDescription: 'Notifications for pending audit items',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Pending Audits',
      'You have $count receipt${count > 1 ? "s" : ""} waiting for verification',
      details,
    );
  }

  static Future<void> showSupervisorAlertNotification({
    required String workerName,
    required String projectName,
    required int receiptCount,
    required double totalAmount,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'supervisor_alert',
      'Supervisor Alerts',
      channelDescription: 'Alerts for supervisors about new submissions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New Submission Alert',
      '$workerName submitted $receiptCount receipt${receiptCount > 1 ? "s" : ""} to $projectName',
      details,
    );
  }
}
