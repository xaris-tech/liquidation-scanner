import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqCloudService {
  static final GroqCloudService _instance = GroqCloudService._internal();
  factory GroqCloudService() => _instance;
  GroqCloudService._internal();

  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  final _isReadyController = StreamController<bool>.broadcast();
  Stream<bool> get isReadyStream => _isReadyController.stream;
  bool _isReady = false;
  bool get isReady => _isReady;

  Future<bool> initialize() async {
    try {
      debugPrint('🔄 Initializing Groq Cloud service...');

      _isReady = true;
      _isReadyController.add(true);
      debugPrint('✅ Groq Cloud ready!');
      return true;
    } catch (e) {
      debugPrint('❌ Groq init error: $e');
      _isReady = false;
      _isReadyController.add(false);
      return false;
    }
  }

  Future<Map<String, dynamic>?> parseReceipt(String rawOcrText) async {
    if (!_isReady) {
      debugPrint('⚠️ Groq not ready, initializing...');
      final success = await initialize();
      if (!success) {
        debugPrint('❌ Groq initialization failed');
        return null;
      }
    }

    try {
      debugPrint('📤 Sending to Groq Cloud (${rawOcrText.length} chars)...');

      final systemPrompt =
          '''You are a receipt parser. Return ONLY valid JSON, no markdown.
IMPORTANT: If the receipt contains VAT or tax, include it as the LAST item in the items array with description "VAT (12%)" or "TAX", quantity: 1, unit_price: [tax amount], total_price: [tax amount].

Schema: { vendor, receipt_date, items: [{description, quantity, unit_price, total_price}], subtotal, tax, total, currency }''';

      final userPrompt = 'Parse this receipt OCR text: $rawOcrText';

      debugPrint('📝 System Prompt: $systemPrompt');
      debugPrint('📝 User Prompt: $userPrompt');

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.1,
          'max_tokens': 1024,
        }),
      );

      debugPrint('📥 Groq response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] ?? '';

        debugPrint('📥 Raw response: "$content"');

        final jsonStr = _extractJson(content as String);
        if (jsonStr != null) {
          debugPrint('✅ Parsed JSON: ${jsonStr.length} chars');
          return json.decode(jsonStr) as Map<String, dynamic>;
        } else {
          debugPrint('❌ No valid JSON found in response');
          return null;
        }
      } else {
        debugPrint(
          '❌ Groq API error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Groq parse error: $e');
      return null;
    }
  }

  String? _extractJson(String response) {
    final trimmed = response.trim();

    if (trimmed.startsWith('```json')) {
      final end = trimmed.lastIndexOf('```');
      if (end > 7) {
        return trimmed.substring(7, end).trim();
      }
    }

    if (trimmed.startsWith('```')) {
      final end = trimmed.lastIndexOf('```');
      if (end > 3) {
        return trimmed.substring(3, end).trim();
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    return trimmed;
  }

  Future<void> dispose() async {
    _isReady = false;
    _isReadyController.add(false);
    await _isReadyController.close();
  }
}
