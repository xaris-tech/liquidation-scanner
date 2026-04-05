import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class DocumentScannerService {
  static final ImagePicker _picker = ImagePicker();

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
      '└─────────────────────────────────────────────────────────────┘',
    );
    debugPrint('');

    try {
      final List<String>? scannedImages =
          await CunningDocumentScanner.getPictures(
            noOfPages: 1,
            isGalleryImportAllowed: true,
          );

      if (scannedImages == null || scannedImages.isEmpty) {
        debugPrint('⚠️ No document detected');
        return await _pickFromGalleryFallback();
      }

      debugPrint('✅ Document detected! ${scannedImages.length} page(s)');

      final scannedPath = scannedImages.first;
      debugPrint('📄 Scanned image: $scannedPath');

      final outputDir = await getTemporaryDirectory();
      final outputFilePath = path.join(
        outputDir.path,
        'scanned_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final scannedFile = File(scannedPath);
      await scannedFile.copy(outputFilePath);

      debugPrint('📤 Output: $outputFilePath');

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
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        debugPrint('❌ No image selected');
        return null;
      }

      debugPrint('📸 Gallery image: ${pickedFile.path}');
      return File(pickedFile.path);
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
