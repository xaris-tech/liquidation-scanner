import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import 'database_provider.dart';

class AnalyticsData {
  final double totalLiquidation;
  final int totalReceipts;
  final int verifiedCount;
  final int pendingCount;
  final int rejectedCount;
  final Map<String, double> spendingByCategory;
  final Map<String, double> spendingByMonth;
  final List<ProjectSpending> projectSpending;

  AnalyticsData({
    required this.totalLiquidation,
    required this.totalReceipts,
    required this.verifiedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.spendingByCategory,
    required this.spendingByMonth,
    required this.projectSpending,
  });
}

class ProjectSpending {
  final int projectId;
  final String projectName;
  final double total;

  ProjectSpending({
    required this.projectId,
    required this.projectName,
    required this.total,
  });
}

final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final db = ref.watch(databaseProvider);

  final receipts = await db.getAllReceipts();
  final projects = await db.getAllProjects();

  double totalLiquidation = 0;
  int verifiedCount = 0;
  int pendingCount = 0;
  int rejectedCount = 0;

  Map<String, double> spendingByCategory = {};
  Map<String, double> spendingByMonth = {};
  Map<int, double> projectSpendingMap = {};

  for (final receipt in receipts) {
    totalLiquidation += receipt.amount;

    if (receipt.status == 'verified') {
      verifiedCount++;
    } else if (receipt.status == 'pending') {
      pendingCount++;
    } else if (receipt.status == 'rejected') {
      rejectedCount++;
    }

    final category = receipt.category ?? 'Uncategorized';
    spendingByCategory[category] =
        (spendingByCategory[category] ?? 0) + receipt.amount;

    final monthKey =
        '${receipt.receiptDate.year}-${receipt.receiptDate.month.toString().padLeft(2, '0')}';
    spendingByMonth[monthKey] =
        (spendingByMonth[monthKey] ?? 0) + receipt.amount;

    projectSpendingMap[receipt.projectId] =
        (projectSpendingMap[receipt.projectId] ?? 0) + receipt.amount;
  }

  final projectSpending = <ProjectSpending>[];
  for (final project in projects) {
    final total = projectSpendingMap[project.id] ?? 0;
    if (total > 0) {
      projectSpending.add(
        ProjectSpending(
          projectId: project.id,
          projectName: project.name,
          total: total,
        ),
      );
    }
  }
  projectSpending.sort((a, b) => b.total.compareTo(a.total));

  return AnalyticsData(
    totalLiquidation: totalLiquidation,
    totalReceipts: receipts.length,
    verifiedCount: verifiedCount,
    pendingCount: pendingCount,
    rejectedCount: rejectedCount,
    spendingByCategory: spendingByCategory,
    spendingByMonth: spendingByMonth,
    projectSpending: projectSpending,
  );
});

final projectAnalyticsProvider = FutureProvider.family<AnalyticsData, int>((
  ref,
  projectId,
) async {
  final db = ref.watch(databaseProvider);

  final receipts = await db.getReceiptsForProject(projectId);
  final project = await db.getProjectById(projectId);

  double totalLiquidation = 0;
  int verifiedCount = 0;
  int pendingCount = 0;
  int rejectedCount = 0;

  Map<String, double> spendingByCategory = {};
  Map<String, double> spendingByMonth = {};

  for (final receipt in receipts) {
    totalLiquidation += receipt.amount;

    if (receipt.status == 'verified') {
      verifiedCount++;
    } else if (receipt.status == 'pending') {
      pendingCount++;
    } else if (receipt.status == 'rejected') {
      rejectedCount++;
    }

    final category = receipt.category ?? 'Uncategorized';
    spendingByCategory[category] =
        (spendingByCategory[category] ?? 0) + receipt.amount;

    final monthKey =
        '${receipt.receiptDate.year}-${receipt.receiptDate.month.toString().padLeft(2, '0')}';
    spendingByMonth[monthKey] =
        (spendingByMonth[monthKey] ?? 0) + receipt.amount;
  }

  return AnalyticsData(
    totalLiquidation: totalLiquidation,
    totalReceipts: receipts.length,
    verifiedCount: verifiedCount,
    pendingCount: pendingCount,
    rejectedCount: rejectedCount,
    spendingByCategory: spendingByCategory,
    spendingByMonth: spendingByMonth,
    projectSpending: [
      ProjectSpending(
        projectId: project.id,
        projectName: project.name,
        total: totalLiquidation,
      ),
    ],
  );
});
