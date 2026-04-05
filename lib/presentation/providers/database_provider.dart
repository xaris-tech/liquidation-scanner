import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final currentUserProvider = StateProvider<User?>((ref) => null);

final projectsProvider = StreamProvider<List<Project>>((ref) {
  final db = ref.watch(databaseProvider);
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null || currentUser.role == 'head') {
    return db.watchAllProjects();
  }
  return db.watchProjectsForUser(currentUser.id);
});

final receiptsProvider = StreamProvider.family<List<Receipt>, int>((
  ref,
  projectId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchReceiptsForProject(projectId);
});

final allReceiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllReceipts();
});

final pendingReceiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPendingReceipts();
});

class ProjectStats {
  final int projectCount;
  final int receiptCount;
  final double totalLiquidation;
  final int pendingCount;

  ProjectStats({
    required this.projectCount,
    required this.receiptCount,
    required this.totalLiquidation,
    required this.pendingCount,
  });
}

final projectStatsProvider = FutureProvider<ProjectStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final projects = await db.getAllProjects();
  final receipts = await db.getAllReceipts();

  final totalLiquidation = receipts.fold(0.0, (sum, r) => sum + r.amount);
  final pendingCount = await db.getPendingReceiptCount();

  return ProjectStats(
    projectCount: projects.length,
    receiptCount: receipts.length,
    totalLiquidation: totalLiquidation,
    pendingCount: pendingCount,
  );
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;
  bool get isHead => user?.role == 'head';
  bool get isWorker => user?.role == 'worker';
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(ref);
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthStateNotifier(this.ref) : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final db = ref.read(databaseProvider);
      final users = await db.getAllUsers();
      if (users.isNotEmpty) {
        state = AuthState(user: users.first);
      } else {
        state = AuthState();
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> loginAsHead() async {
    state = AuthState(isLoading: true);
    try {
      final db = ref.read(databaseProvider);
      final users = await db.getAllUsers();
      final headUser = users.firstWhere(
        (u) => u.role == 'head',
        orElse: () => users.first,
      );
      state = AuthState(user: headUser);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> loginAsWorker() async {
    state = AuthState(isLoading: true);
    try {
      final db = ref.read(databaseProvider);
      final users = await db.getAllUsers();
      final workerUser = users.firstWhere(
        (u) => u.role == 'worker',
        orElse: () => users.first,
      );
      state = AuthState(user: workerUser);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  void logout() {
    state = AuthState();
  }
}
