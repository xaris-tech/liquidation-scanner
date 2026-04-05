import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_ocr_kit/flutter_ocr_kit.dart';
import 'native_llm_service.dart';
import 'groq_cloud_service.dart';

class ReceiptItem {
  final String name;
  final int? quantity;
  final double? unitPrice;
  final double? totalPrice;

  ReceiptItem({
    required this.name,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });
}

class ReceiptExtractionResult {
  final String? vendor;
  final double? amount;
  final DateTime? date;
  final String? category;
  final double confidence;
  final String? rawText;
  final String? error;
  final List<ReceiptItem> items;
  final String extractionMethod;

  ReceiptExtractionResult({
    this.vendor,
    this.amount,
    this.date,
    this.category,
    this.confidence = 0.0,
    this.rawText,
    this.error,
    this.items = const [],
    this.extractionMethod = 'ml_kit',
  });

  bool get isValid => vendor != null && amount != null && date != null;
}

class AiExtractionService {
  static final TextRecognizer _mlKitRecognizer = TextRecognizer();
  static bool _isNativeLlmReady = false;

  static Future<ReceiptExtractionResult> extractFromImage(
    String imagePath,
  ) async {
    debugPrint('');
    debugPrint(
      '╔═══════════════════════════════════════════════════════════════╗',
    );
    debugPrint(
      '║       📸 RECEIPT EXTRACTION PIPELINE (FULL EDGE AI)          ║',
    );
    debugPrint(
      '╚═══════════════════════════════════════════════════════════════╝',
    );
    debugPrint('');

    String rawText = '';

    debugPrint(
      '┌─────────────────────────────────────────────────────────────┐',
    );
    debugPrint(
      '│ 📷 STAGE 1: OCR (Edge AI)                                   │',
    );
    debugPrint(
      '├─────────────────────────────────────────────────────────────┤',
    );
    debugPrint('│   Primary: flutter_ocr_kit (ONNX)                         │');
    debugPrint('│   Fallback: ML Kit                                        │');
    debugPrint(
      '└─────────────────────────────────────────────────────────────┘',
    );
    debugPrint('');

    try {
      debugPrint('🔄 Running Edge AI OCR...');
      rawText = await _runFlutterOcr(imagePath);

      if (rawText.isEmpty || rawText.length < 5) {
        debugPrint('⚠️ Empty result, trying ML Kit...');
        rawText = await _runMlKitOcr(imagePath);
      }

      if (rawText.isEmpty) {
        return ReceiptExtractionResult(error: 'No text found', confidence: 0.0);
      }

      debugPrint('✅ OCR Complete! (${rawText.length} chars)');
      debugPrint('');
      debugPrint(
        '┌─────────────────────────────────────────────────────────────┐',
      );
      debugPrint(
        '│ 📄 RAW OCR TEXT PREVIEW                                     │',
      );
      debugPrint(
        '├─────────────────────────────────────────────────────────────┤',
      );
      final preview = rawText.length > 500
          ? '${rawText.substring(0, 500)}...\n[truncated ${rawText.length - 500} more chars]'
          : rawText;
      debugPrint(preview);
      debugPrint(
        '└─────────────────────────────────────────────────────────────┘',
      );
      debugPrint('');
    } catch (e) {
      debugPrint('❌ OCR failed: $e');
      try {
        rawText = await _runMlKitOcr(imagePath);
      } catch (e2) {
        return ReceiptExtractionResult(error: 'OCR failed', confidence: 0.0);
      }
    }

    debugPrint(
      '┌─────────────────────────────────────────────────────────────┐',
    );
    debugPrint('│ 🧠 STAGE 2: Groq Cloud Parser (LLM)                    │');
    debugPrint(
      '├─────────────────────────────────────────────────────────────┤',
    );
    debugPrint('│   Running: Groq Cloud API                              │');
    debugPrint('│   Model: llama-3.1-70b-versatile                    │');
    debugPrint(
      '└─────────────────────────────────────────────────────────────┘',
    );
    debugPrint('');

    ReceiptExtractionResult? groqResult;

    try {
      debugPrint('📤 Sending to Groq Cloud...');
      groqResult = await _parseWithGroq(rawText);
      if (groqResult != null) {
        debugPrint('📥 Received from Groq: SUCCESS');
        _logResult(groqResult);
        groqResult = ReceiptExtractionResult(
          vendor: groqResult?.vendor,
          amount: groqResult?.amount,
          date: groqResult?.date,
          category: groqResult?.category,
          confidence: groqResult?.confidence ?? 0.9,
          rawText: rawText,
          error: groqResult?.error,
          items: groqResult?.items ?? [],
          extractionMethod: groqResult?.extractionMethod ?? 'groq_cloud',
        );
        return groqResult;
      } else {
        debugPrint('📥 Received from Groq: FAILED (null result)');
      }
    } catch (e) {
      debugPrint('   ⚠️ Groq failed: $e');
    }

    debugPrint(
      '┌─────────────────────────────────────────────────────────────┐',
    );
    debugPrint('│ 🔧 STAGE 3: Regex Fallback                              │');
    debugPrint(
      '├─────────────────────────────────────────────────────────────┤',
    );
    debugPrint(
      '└─────────────────────────────────────────────────────────────┘',
    );
    debugPrint('');

    final regexResult = _parseWithRegex(rawText);
    _logResult(regexResult);

    return ReceiptExtractionResult(
      vendor: regexResult.vendor,
      amount: regexResult.amount,
      date: regexResult.date,
      category: regexResult.category,
      confidence: regexResult.confidence,
      rawText: rawText,
      error: regexResult.error,
      items: regexResult.items,
      extractionMethod: regexResult.extractionMethod,
    );
  }

  static Future<String> _runFlutterOcr(String imagePath) async {
    try {
      final result = await OcrKit.recognizeNative(imagePath);
      return result?.fullText ?? '';
    } catch (e) {
      debugPrint('   ❌ flutter_ocr_kit error: $e');
      rethrow;
    }
  }

  static Future<String> _runMlKitOcr(String imagePath) async {
    debugPrint('   📷 Using ML Kit fallback...');
    final inputImage = InputImage.fromFilePath(imagePath);
    final text = await _mlKitRecognizer.processImage(inputImage);
    return text.text;
  }

  static Future<ReceiptExtractionResult?> _parseWithGroq(String text) async {
    try {
      debugPrint('   📤 → Sending ${text.length} chars to Groq Cloud');

      final groqService = GroqCloudService();
      final result = await groqService.parseReceipt(text);

      if (result != null) {
        debugPrint('   📥 ← Received from Groq: SUCCESS');

        final items = <ReceiptItem>[];
        if (result['items'] != null) {
          for (final item in result['items'] as List) {
            items.add(
              ReceiptItem(
                name: item['description'] ?? item['name'] ?? '',
                quantity: item['quantity'],
                unitPrice: item['unit_price']?.toDouble(),
                totalPrice: item['total_price']?.toDouble(),
              ),
            );
          }
        }

        DateTime? parsedDate;
        if (result['receipt_date'] != null) {
          try {
            parsedDate = DateTime.parse(result['receipt_date']);
          } catch (_) {}
        }

        return ReceiptExtractionResult(
          vendor: result['vendor'],
          amount: result['total']?.toDouble() ?? result['subtotal']?.toDouble(),
          date: parsedDate,
          category: result['category'],
          confidence: 0.9,
          items: items,
          extractionMethod: 'groq_cloud',
        );
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ Groq parse error: $e');
      return null;
    }
  }

  static Future<ReceiptExtractionResult?> _parseWithNativeLlm(
    String text,
  ) async {
    try {
      if (!_isNativeLlmReady) {
        debugPrint('   🔧 Initializing Native LLM...');
        final initResult = await NativeLlmService.initialize();
        debugPrint('   🔧 Init result: $initResult');
        _isNativeLlmReady = true;
      }

      debugPrint('   📤 → Sending ${text.length} chars to Native Layer');
      debugPrint(
        '   📤 Text preview: ${text.substring(0, text.length.clamp(0, 200))}...',
      );

      final prompt = '''$text
Extract JSON with: vendor, amount, date (MM/DD/YYYY), items [{name, price}]. Return ONLY JSON.''';

      final result = await NativeLlmService.generate(prompt);

      if (result != null && result.isNotEmpty) {
        debugPrint('   📥 ← Received ${result.length} chars from Native Layer');
        debugPrint(
          '   📥 Result: ${result.substring(0, result.length.clamp(0, 200))}...',
        );

        try {
          final json = jsonDecode(result) as Map<String, dynamic>;

          final items = <ReceiptItem>[];
          if (json['items'] != null && json['items'] is List) {
            for (final item in json['items'] as List) {
              items.add(
                ReceiptItem(
                  name: item['name']?.toString() ?? 'Unknown',
                  unitPrice: (item['price'] as num?)?.toDouble(),
                  totalPrice: (item['price'] as num?)?.toDouble(),
                ),
              );
            }
          }

          DateTime? date;
          if (json['date'] != null && json['date'].toString().isNotEmpty) {
            try {
              date = DateTime.parse(json['date'] as String);
            } catch (_) {
              try {
                final parts = json['date'].toString().split('/');
                if (parts.length == 3) {
                  var y = int.parse(parts[2]);
                  if (y < 100) y += 2000;
                  date = DateTime(y, int.parse(parts[0]), int.parse(parts[1]));
                }
              } catch (_) {}
            }
          }

          return ReceiptExtractionResult(
            vendor: json['vendor'] as String?,
            amount: (json['amount'] as num?)?.toDouble(),
            date: date,
            category: _inferCategory(text),
            confidence: 0.85,
            rawText: text,
            items: items,
            extractionMethod: 'native_onnx_llm',
          );
        } catch (e) {
          debugPrint('   ⚠️ JSON parse error: $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ Native LLM error: $e');
      return null;
    }
  }

  static ReceiptExtractionResult _parseWithRegex(String text) {
    debugPrint('   🔧 Running regex parser...');

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String? vendor;
    double? amount;
    DateTime? date;
    String? category;
    List<ReceiptItem> items = [];

    final skipWords = [
      'subtotal',
      'total',
      'tax',
      'discount',
      'payment',
      'change',
      'cash',
      'vat',
      'tin',
      'thank you',
      'receipt',
      'date',
      'cashier',
      'trx',
      'str',
      'reg',
      'qty',
      'signature',
      'customer',
    ];

    for (final line in lines) {
      final itemMatch = RegExp(
        r'^([A-Za-z][A-Za-z\s]{2,35})\s+(\d+[.,]\d{2,3})$',
      ).firstMatch(line);
      if (itemMatch != null) {
        final name = itemMatch.group(1)?.trim() ?? '';
        final price = double.tryParse(
          itemMatch.group(2)?.replaceAll(',', '.') ?? '',
        );

        if (name.isNotEmpty &&
            name.length > 3 &&
            price != null &&
            price > 0 &&
            price < 10000) {
          final lower = name.toLowerCase();
          if (!skipWords.any((w) => lower.contains(w))) {
            items.add(
              ReceiptItem(
                name: name,
                quantity: 1,
                unitPrice: price,
                totalPrice: price,
              ),
            );
          }
        }
      }

      if (line.toLowerCase().contains('total') &&
          !line.toLowerCase().contains('subtotal')) {
        final m = RegExp(r'(\d+[.,]\d{2})').firstMatch(line);
        if (m != null) {
          final p = double.tryParse(m.group(1)!.replaceAll(',', '.'));
          if (p != null && p > 0) amount = p;
        }
      }

      if (vendor == null && line.length > 3 && line.length < 40) {
        final cleaned = line.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
        if (cleaned.isNotEmpty && !cleaned.contains(RegExp(r'^\d+$'))) {
          vendor = cleaned;
        }
      }

      if (date == null) {
        final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(line);
        if (m != null) {
          try {
            var y = int.parse(m.group(3)!);
            if (y < 100) y += 2000;
            date = DateTime(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
          } catch (_) {}
        }
      }
    }

    if (items.isNotEmpty && amount == null) {
      amount = items.fold<double>(0.0, (s, i) => s + (i.totalPrice ?? 0));
    }

    category = _inferCategory(text);

    return ReceiptExtractionResult(
      vendor: vendor,
      amount: amount,
      date: date,
      category: category,
      confidence: 0.70,
      rawText: text,
      items: items,
      extractionMethod: 'flutter_ocr_kit_regex',
    );
  }

  static String _inferCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('food') ||
        lower.contains('restaurant') ||
        lower.contains('mcdonalds') ||
        lower.contains('jollibee') ||
        lower.contains('burger') ||
        lower.contains('coffee'))
      return 'Food';
    if (lower.contains('gas') ||
        lower.contains('fuel') ||
        lower.contains('petron') ||
        lower.contains('shell'))
      return 'Transport';
    if (lower.contains('hardware') || lower.contains('home depot'))
      return 'Materials';
    if (lower.contains('tools') || lower.contains('makita')) return 'Tools';
    if (lower.contains('office') || lower.contains('stationery'))
      return 'Supplies';
    if (lower.contains('equipment')) return 'Equipment';
    return 'Other';
  }

  static void _logResult(ReceiptExtractionResult result) {
    debugPrint('');
    debugPrint(
      '┌─────────────────────────────────────────────────────────────┐',
    );
    debugPrint('│ 📊 EXTRACTION RESULT (Edge AI Pipeline)                   │');
    debugPrint(
      '├─────────────────────────────────────────────────────────────┤',
    );
    debugPrint('│   Vendor:    ${result.vendor ?? "❌ Not found"}');
    debugPrint(
      '│   Amount:    ${result.amount != null ? "₱${result.amount!.toStringAsFixed(2)}" : "❌ Not found"}',
    );
    debugPrint(
      '│   Date:      ${result.date != null ? "${result.date!.month}/${result.date!.day}/${result.date!.year}" : "❌ Not found"}',
    );
    debugPrint('│   Category:  ${result.category ?? "❌ Not found"}');
    debugPrint('│   Method:    ${result.extractionMethod}');
    debugPrint('│   Items:     ${result.items.length} extracted');
    debugPrint(
      '└─────────────────────────────────────────────────────────────┘',
    );
    debugPrint('');
  }

  static Future<void> dispose() async {
    await _mlKitRecognizer.close();
    await NativeLlmService.dispose();
  }
}
