import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/document_scanner_service.dart';
import '../../presentation/screens/projects/projects_screen.dart';
import '../../presentation/screens/project_detail/project_detail_screen.dart';
import '../../presentation/screens/review/review_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/audit/audit_verification_screen.dart';
import '../../presentation/screens/audit/pending_audits_screen.dart';
import '../../presentation/screens/camera/project_select_screen.dart';
import '../../presentation/screens/analytics/analytics_screen.dart';
import '../../presentation/screens/receipts/receipt_gallery_screen.dart';
import '../../presentation/widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/projects',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/projects',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProjectsScreen()),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AnalyticsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final projectId = extra?['projectId'] as int?;
        return MaterialPage(
          child: _CameraScreenWithProject(projectId: projectId),
        );
      },
    ),
    GoRoute(
      path: '/project/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final projectId = int.parse(state.pathParameters['id']!);
        return ProjectDetailScreen(projectId: projectId);
      },
    ),
    GoRoute(
      path: '/review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ReviewScreen(
          imagePath: extra?['imagePath'] as String?,
          projectId: extra?['projectId'] as int?,
        );
      },
    ),
    GoRoute(
      path: '/audit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final receiptId = int.parse(state.pathParameters['id']!);
        return AuditVerificationScreen(receiptId: receiptId);
      },
    ),
    GoRoute(
      path: '/pending-audits',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PendingAuditsScreen(),
    ),
    GoRoute(
      path: '/select-project',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final imagePath = state.extra as String?;
        return ProjectSelectScreen(imagePath: imagePath);
      },
    ),
    GoRoute(
      path: '/project/:id/gallery',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final projectId = int.parse(state.pathParameters['id']!);
        return ReceiptGalleryScreen(projectId: projectId);
      },
    ),
  ],
);

class _CameraScreenWithProject extends StatefulWidget {
  final int? projectId;

  const _CameraScreenWithProject({this.projectId});

  @override
  State<_CameraScreenWithProject> createState() =>
      _CameraScreenWithProjectState();
}

class _CameraScreenWithProjectState extends State<_CameraScreenWithProject>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;
  String _statusMessage = 'Preparing Scanner';
  String _subMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanDocument();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _statusMessage = 'Opening Scanner';
      _subMessage = 'Please wait...';
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _scanDocument() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Opening Scanner';
      _subMessage = 'Please wait...';
    });

    try {
      final result = await DocumentScannerService.scanFromGallery();

      if (!mounted) return;

      if (result != null) {
        context.push(
          '/review',
          extra: {'imagePath': result.path, 'projectId': widget.projectId},
        );
      } else {
        context.pop();
      }
    } catch (e) {
      debugPrint('[Scanner] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scanner error: $e')));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: true,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rotateController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateController.value * 2 * 3.14159,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: _LoadingSpinnerPainter(
                              color: const Color(0xFF6366F1),
                              backgroundColor: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subMessage,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSpinnerPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;

  _LoadingSpinnerPainter({required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius - 2, bgPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      0,
      3.14159 * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
