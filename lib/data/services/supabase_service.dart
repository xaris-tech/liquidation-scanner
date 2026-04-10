import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isConfigured = false;

  static const String supabaseUrl = 'https://qexvtratttwkcdxevrdy.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_BVCMuBH1r7II6C0bycVXTA_2Er32_Ay';

  static Future<void> initialize() async {
    if (_isConfigured) return;

    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _client = Supabase.instance.client;
      _isConfigured = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }
  }

  static SupabaseClient? get client => _client;

  static bool get isConfigured => _isConfigured;

  static Future<void> uploadReceiptImage(
    File imageFile,
    String receiptId,
  ) async {
    if (!_isConfigured || _client == null) return;

    try {
      final fileName =
          'receipts/$receiptId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client!.storage.from('receipt-images').upload(fileName, imageFile);
      final publicUrl = _client!.storage
          .from('receipt-images')
          .getPublicUrl(fileName);
      debugPrint('Image uploaded: $publicUrl');
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
  }

  static Future<String?> uploadReceiptAndGetUrl(
    File imageFile,
    String receiptId,
  ) async {
    if (!_isConfigured || _client == null) return null;

    try {
      final fileName =
          'receipts/$receiptId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client!.storage.from('receipt-images').upload(fileName, imageFile);
      return _client!.storage.from('receipt-images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  static Future<void> syncProjectToCloud(dynamic project) async {
    if (!_isConfigured || _client == null) return;

    try {
      await _client!.from('projects').upsert({
        'id': project.id,
        'name': project.name,
        'description': project.description,
        'location': project.location,
        'phase': project.phase,
        'total_budget': project.totalBudget,
        'created_at': project.createdAt.toIso8601String(),
        'updated_at': project.updatedAt.toIso8601String(),
      });
      debugPrint('Project synced to cloud: ${project.name}');
    } catch (e) {
      debugPrint('Error syncing project: $e');
    }
  }

  static Future<void> syncReceiptToCloud(dynamic receipt) async {
    if (!_isConfigured || _client == null) return;

    try {
      await _client!.from('receipts').upsert({
        'id': receipt.id,
        'project_id': receipt.projectId,
        'vendor': receipt.vendor,
        'amount': receipt.amount,
        'receipt_date': receipt.receiptDate.toIso8601String(),
        'category': receipt.category,
        'notes': receipt.notes,
        'image_path': receipt.imagePath,
        'line_items': receipt.lineItems,
        'ai_confidence': receipt.aiConfidence,
        'status': receipt.status,
        'created_at': receipt.createdAt.toIso8601String(),
        'updated_at': receipt.updatedAt.toIso8601String(),
      });
      debugPrint('Receipt synced to cloud: ${receipt.vendor}');
    } catch (e) {
      debugPrint('Error syncing receipt: $e');
    }
  }

  static Future<void> sendAuditNotification({
    required String email,
    required String vendor,
    required double amount,
    required String status,
  }) async {
    if (!_isConfigured || _client == null) return;

    try {
      await _client!.from('notifications').insert({
        'email': email,
        'type': 'audit_status',
        'title': 'Receipt $status',
        'message': 'Receipt from $vendor (\$$amount) has been $status',
        'read': false,
      });
      debugPrint('Notification sent to: $email');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static Future<void> signOut() async {
    if (!_isConfigured || _client == null) return;
    await _client!.auth.signOut();
  }

  static Future<void> submitFeedback({
    required String type,
    required String title,
    required String description,
    String? email,
  }) async {
    if (!_isConfigured || _client == null) return;

    try {
      await _client!.from('feedback').insert({
        'type': type,
        'title': title,
        'description': description,
        'email': email,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Feedback submitted: $type - $title');
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getFeedbackTickets() async {
    if (!_isConfigured || _client == null) return [];

    try {
      final response = await _client!
          .from('feedback')
          .select()
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      debugPrint('Error fetching feedback: $e');
      return [];
    }
  }

  static Future<void> updateFeedbackStatus(int id, String status) async {
    if (!_isConfigured || _client == null) return;

    try {
      await _client!
          .from('feedback')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      debugPrint('Feedback status updated: $id -> $status');
    } catch (e) {
      debugPrint('Error updating feedback status: $e');
    }
  }
}
