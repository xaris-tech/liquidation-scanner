import 'package:flutter/material.dart';

class RealTimeEdgeDetectionWidget extends StatefulWidget {
  final Widget child;
  final bool isProcessing;
  final Function(List<Offset>?)? onEdgesDetected;

  const RealTimeEdgeDetectionWidget({
    super.key,
    required this.child,
    this.isProcessing = false,
    this.onEdgesDetected,
  });

  @override
  State<RealTimeEdgeDetectionWidget> createState() =>
      _RealTimeEdgeDetectionWidgetState();
}

class _RealTimeEdgeDetectionWidgetState
    extends State<RealTimeEdgeDetectionWidget> {
  bool _isDocumentDetected = false;

  void updateDetectionStatus(bool detected) {
    if (mounted) {
      setState(() {
        _isDocumentDetected = detected;
      });
      widget.onEdgesDetected?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        CustomPaint(
          painter: _ScannerOverlayPainter(isDetected: _isDocumentDetected),
        ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final bool isDetected;

  _ScannerOverlayPainter({this.isDetected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final guideColor = isDetected ? Colors.green : Colors.white;
    final fillColor = (isDetected ? Colors.green : Colors.white).withValues(
      alpha: 0.05,
    );

    final drawEdges = [
      Offset(size.width * 0.08, size.height * 0.12),
      Offset(size.width * 0.92, size.height * 0.12),
      Offset(size.width * 0.92, size.height * 0.65),
      Offset(size.width * 0.08, size.height * 0.65),
    ];

    final paint = Paint()
      ..color = guideColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(drawEdges[0].dx, drawEdges[0].dy)
      ..lineTo(drawEdges[1].dx, drawEdges[1].dy)
      ..lineTo(drawEdges[2].dx, drawEdges[2].dy)
      ..lineTo(drawEdges[3].dx, drawEdges[3].dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    for (int i = 0; i < 4; i++) {
      final corner = drawEdges[i];

      final cornerPaint = Paint()
        ..color = guideColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(corner, 12, cornerPaint);

      final innerPaint = Paint()
        ..color = (isDetected ? Colors.green.shade700 : Colors.grey.shade700)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(corner, 6, innerPaint);
    }

    if (!isDetected) {
      final text = 'Align receipt within the frame';
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, size.height * 0.72),
      );
    } else {
      final text = 'Receipt detected';
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, size.height * 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return isDetected != oldDelegate.isDetected;
  }
}
