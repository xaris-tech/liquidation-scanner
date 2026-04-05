import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/projects/projects_screen.dart';
import '../../presentation/screens/project_detail/project_detail_screen.dart';
import '../../presentation/screens/camera/camera_screen.dart';
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
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login';
    final isSplash = state.matchedLocation == '/';

    if (!isLoggedIn && !isAuthRoute && !isSplash) {
      return '/login';
    }

    if (isLoggedIn && (isAuthRoute || isSplash)) {
      return '/projects';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
          path: '/scan',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CameraScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
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
      path: '/analytics',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AnalyticsScreen(),
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
