import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ScannerScreen extends StatefulWidget {
  final String imagePath;

  const ScannerScreen({super.key, required this.imagePath});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late List<Offset> _corners;
  bool _isProcessing = false;
  int _selectedFilter = 0;
  String? _processedImagePath;

  final List<String> _filterNames = [
    'Original',
    'Auto',
    'Grayscale',
    'B&W',
    'Enhanced',
  ];
  final List<Color> _filterColors = [
    Colors.white,
    Colors.blue,
    Colors.grey,
    Colors.black,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _corners = [
      const Offset(50, 50),
      const Offset(250, 50),
      const Offset(250, 350),
      const Offset(50, 350),
    ];
    _processedImagePath = widget.imagePath;
  }

  void _updateCorner(int index, Offset newPosition) {
    setState(() {
      _corners[index] = newPosition;
    });
  }

  Future<void> _applyPerspectiveTransform() async {
    setState(() => _isProcessing = true);

    try {
      final originalFile = File(widget.imagePath);
      final originalImage = img.decodeImage(await originalFile.readAsBytes());

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      img.Image processed;

      switch (_selectedFilter) {
        case 1:
          processed = img.adjustColor(
            originalImage,
            contrast: 1.2,
            brightness: 1.1,
          );
          break;
        case 2:
          processed = img.grayscale(originalImage);
          break;
        case 3:
          processed = img.grayscale(originalImage);
          processed = img.adjustColor(processed, contrast: 1.5);
          for (int y = 0; y < processed.height; y++) {
            for (int x = 0; x < processed.width; x++) {
              final pixel = processed.getPixel(x, y);
              final luminance = pixel.luminance;
              if (luminance > 128) {
                processed.setPixel(x, y, img.ColorRgb8(255, 255, 255));
              } else {
                processed.setPixel(x, y, img.ColorRgb8(0, 0, 0));
              }
            }
          }
          break;
        case 4:
          processed = img.adjustColor(
            originalImage,
            contrast: 1.3,
            brightness: 1.15,
            saturation: 1.1,
          );
          break;
        default:
          processed = originalImage;
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/scanned_$timestamp.jpg';

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(processed, quality: 90));

      if (mounted) {
        setState(() {
          _processedImagePath = outputPath;
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image processed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
    }
  }

  void _resetCorners(Size imageSize) {
    final padding = 20.0;
    setState(() {
      _corners = [
        Offset(padding, padding),
        Offset(imageSize.width - padding, padding),
        Offset(imageSize.width - padding, imageSize.height - padding),
        Offset(padding, imageSize.height - padding),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Corners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final size = MediaQuery.of(context).size;
              _resetCorners(Size(size.width - 40, size.height * 0.5));
            },
            tooltip: 'Reset corners',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildImageWithCorners()),
          _buildFilterBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImageWithCorners() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(_processedImagePath ?? widget.imagePath),
                    fit: BoxFit.contain,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _CornerPainter(_corners)),
              ),
              ...List.generate(4, (index) {
                return Positioned(
                  left: _corners[index].dx - 15,
                  top: _corners[index].dy - 15,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      final newPos = Offset(
                        (_corners[index].dx + details.delta.dx).clamp(
                          0,
                          constraints.maxWidth,
                        ),
                        (_corners[index].dy + details.delta.dy).clamp(
                          0,
                          constraints.maxHeight,
                        ),
                      );
                      _updateCorner(index, newPos);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 80,
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterNames.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.white30,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _filterColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _filterNames[index],
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white70,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      await _applyPerspectiveTransform();
                      if (mounted && _processedImagePath != null) {
                        context.pushReplacement(
                          '/select-project',
                          extra: _processedImagePath,
                        );
                      }
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isProcessing ? 'Processing...' : 'Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _CornerPainter extends CustomPainter {
  final List<Offset> corners;

  _CornerPainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return corners != oldDelegate.corners;
  }
}
