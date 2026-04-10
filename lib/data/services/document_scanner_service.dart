import 'dart:io';
// ignore: unused_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';

class DocumentScannerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String> _getPermanentStoragePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(path.join(appDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir.path;
  }

  static Future<File?> scanDocument({
    required bool fromCamera,
    String? outputPath,
  }) async {
    debugPrint('');
    debugPrint(
      '╔═══════════════════════════════════════════════════════════════╗',
    );
    debugPrint(
      '║        📷 DOCUMENT SCANNER (Auto Edge Detection)              ║',
    );
    debugPrint(
      '╚═══════════════════════════════════════════════════════════════╝',
    );
    debugPrint('');

    try {
      if (fromCamera) {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 90,
        );

        if (pickedFile == null) {
          debugPrint('❌ No image captured from camera');
          return null;
        }

        debugPrint('📸 Camera capture: ${pickedFile.path}');
        return File(pickedFile.path);
      } else {
        return await scanFromGallery();
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  static Future<File?> scanFromGallery() async {
    debugPrint(
      '┌─────────────────────────────────────────────────────────────┐',
    );
    debugPrint('│ 🔍 STAGE 1: Edge Detection (Cunning Document Scanner)   │');
    debugPrint(
      '├─────────────────────────────────────────────────────────────┤',
    );
    debugPrint('│   Using cunning_document_scanner for auto-cropping...    │');
    debugPrint(
      '└─────────────────────────���───────────────────────────────────┘',
    );
    debugPrint('');

    try {
      debugPrint(
        '[DocumentScannerService] Calling CunningDocumentScanner.getPictures...',
      );

      List<String>? scannedImages;

      try {
        scannedImages =
            await CunningDocumentScanner.getPictures(
              noOfPages: 1,
              isGalleryImportAllowed: true,
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint(
                  '[DocumentScannerService] TIMEOUT - scanner did not return',
                );
                return null;
              },
            );
      } catch (e) {
        debugPrint('[DocumentScannerService] Scanner exception: $e');
        return await _pickFromGalleryFallback();
      }

      if (scannedImages == null || scannedImages.isEmpty) {
        debugPrint('⚠️ No document detected or user cancelled');
        return await _pickFromGalleryFallback();
      }

      final scannedPath = scannedImages.first;
      final permanentDir = await _getPermanentStoragePath();
      final fileName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFilePath = path.join(permanentDir, fileName);

      try {
        final scannedFile = File(scannedPath);
        if (await scannedFile.exists()) {
          await scannedFile.copy(outputFilePath);
        } else {
          debugPrint('⚠️ Scanned file does not exist');
          return await _pickFromGalleryFallback();
        }
      } catch (e) {
        debugPrint('⚠️ Error copying scanned file: $e');
        return await _pickFromGalleryFallback();
      }

      try {
        await Gal.putImage(outputFilePath);
      } catch (e) {
        debugPrint('⚠️ Error saving to gallery: $e');
      }

      return File(outputFilePath);
    } catch (e) {
      debugPrint('⚠️ Scanner error: $e');
      return await _pickFromGalleryFallback();
    }
  }

  static Future<File?> _pickFromGalleryFallback() async {
    debugPrint('');
    debugPrint('🔄 Falling back to gallery picker...');

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        debugPrint('❌ No image selected');
        return null;
      }

      final permanentDir = await _getPermanentStoragePath();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFilePath = path.join(permanentDir, fileName);

      try {
        final picked = File(pickedFile.path);
        await picked.copy(outputFilePath);
      } catch (e) {
        debugPrint('❌ Error copying file: $e');
        return File(pickedFile.path);
      }

      return File(outputFilePath);
    } catch (e) {
      debugPrint('❌ Fallback error: $e');
      return null;
    }
  }

  static Future<Uint8List?> imageToBytes(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  static Future<File?> pickAndScan({bool fromCamera = true}) async {
    return await scanDocument(fromCamera: fromCamera);
  }

  static Future<File?> pickAndProcess({
    bool fromCamera = true,
    bool applyAutoScan = true,
  }) async {
    if (applyAutoScan) {
      return await scanDocument(fromCamera: fromCamera);
    } else {
      final XFile? pickedFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    }
  }
}
