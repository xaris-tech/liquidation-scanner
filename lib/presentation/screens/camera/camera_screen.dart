import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/document_scanner_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchScanner();
    });
  }

  Future<void> _launchScanner() async {
    try {
      final result = await DocumentScannerService.scanFromGallery();
      if (result != null && mounted) {
        context.push(
          '/review',
          extra: {'imagePath': result.path, 'projectId': null},
        );
      }
    } catch (e) {
      debugPrint('Scanner error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: SizedBox.shrink()),
    );
  }
}
