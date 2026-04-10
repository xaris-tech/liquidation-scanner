import 'package:flutter/services.dart';

class NativeLlmService {
  static const MethodChannel _channel = MethodChannel('com.liquify.app/llm');

  static bool _isInitialized = false;

  static Future<String?> initialize() async {
    if (_isInitialized) return 'already initialized';

    try {
      final result = await _channel.invokeMethod<String>('initialize');
      _isInitialized = true;
      return result;
    } catch (e) {
      return 'Failed to initialize: $e';
    }
  }

  static Future<String?> generate(String prompt) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
      });
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod<String>('dispose');
      _isInitialized = false;
    } catch (_) {}
  }
}
