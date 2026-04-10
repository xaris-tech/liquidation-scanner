import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  final _isReadyController = StreamController<bool>.broadcast();
  Stream<bool> get isReadyStream => _isReadyController.stream;
  bool _isReady = false;
  bool get isReady => _isReady;

  InferenceModel? _model;
  InferenceChat? _chat;

  Future<bool> initialize() async {
    try {
      debugPrint('🔄 Initializing Local LLM service...');

      await FlutterGemma.initialize();

      final isInstalled = await FlutterGemma.isModelInstalled(
        'gemma3-1b-it-int4.task',
      );

      if (!isInstalled) {
        debugPrint('📥 Model not installed, loading from assets...');
        await _loadBundledModel();
      }

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 512,
        preferredBackend: PreferredBackend.cpu,
      );

      if (_model != null) {
        _chat = await _model!.createChat(temperature: 0.1);

        _isReady = true;
        _isReadyController.add(true);
        debugPrint('✅ Local LLM ready!');
        return true;
      } else {
        debugPrint('❌ Model is null');
        _isReady = false;
        _isReadyController.add(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Local LLM init error: $e');
      _isReady = false;
      _isReadyController.add(false);
      return false;
    }
  }

  Future<void> _loadBundledModel() async {
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromAsset('models/gemma3-1b-it-int4.task').install();

      debugPrint('✅ Model loaded from assets successfully');
    } catch (e) {
      debugPrint('❌ Model load error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> parseReceipt(String rawOcrText) async {
    if (!_isReady || _model == null || _chat == null) {
      debugPrint('⚠️ Local LLM not ready, initializing...');
      final success = await initialize();
      if (!success) {
        debugPrint('❌ Local LLM initialization failed');
        return null;
      }
    }

    try {
      debugPrint('📤 Sending to Local LLM (${rawOcrText.length} chars)...');

      final systemPrompt =
          '''You are a receipt parser. Return ONLY valid JSON, no markdown.
IMPORTANT: If the receipt contains VAT or tax, include it as the LAST item in the items array with description "VAT (12%)" or "TAX", quantity: 1, unit_price: [tax amount], total_price: [tax amount].

Schema: { vendor, receipt_date, items: [{description, quantity, unit_price, total_price}], subtotal, tax, total, currency }''';

      final userPrompt = 'Parse this receipt OCR text: $rawOcrText';

      debugPrint('📝 System Prompt: $systemPrompt');
      debugPrint('📝 User Prompt: $userPrompt');

      await _chat!.addQueryChunk(Message.text(text: userPrompt, isUser: true));

      final response = await _chat!.generateChatResponse();
      String responseText;

      if (response is TextResponse) {
        responseText = response.token;
        debugPrint('📥 Raw response: "$responseText"');
      } else {
        debugPrint('❌ Unexpected response type: ${response.runtimeType}');
        return null;
      }

      debugPrint('📥 LLM response: ${responseText.length} chars');

      final jsonStr = _extractJson(responseText);
      if (jsonStr != null) {
        debugPrint('✅ Parsed JSON: ${jsonStr.length} chars');
        return json.decode(jsonStr) as Map<String, dynamic>;
      } else {
        debugPrint('❌ No valid JSON found in response');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Local LLM parse error: $e');
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
    _model?.close();
    _isReady = false;
    _isReadyController.add(false);
    await _isReadyController.close();
  }
}
