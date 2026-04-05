import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get email => text().unique().withLength(min: 1, max: 200)();
  TextColumn get role => text().withDefault(const Constant('worker'))();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get phase => text().nullable()();
  RealColumn get totalBudget => real().withDefault(const Constant(0.0))();
  IntColumn get createdById => integer().references(Users, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ProjectAssignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get assignedAt => dateTime().withDefault(currentDateAndTime)();
}

class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get uploadedById => integer().references(Users, #id).nullable()();
  TextColumn get vendor => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  DateTimeColumn get receiptDate => dateTime()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get lineItems => text().nullable()();
  RealColumn get aiConfidence => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get verifiedById => integer().references(Users, #id).nullable()();
  TextColumn get auditorNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId => integer().references(Receipts, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [Users, Projects, ProjectAssignments, Receipts, AuditLogs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedInitialData();
      },
    );
  }

  Future<void> _seedInitialData() async {
    final adminId = await into(users).insert(
      UsersCompanion.insert(
        name: 'Admin User',
        email: 'admin@example.com',
        role: const Value('head'),
      ),
    );

    final workerId = await into(users).insert(
      UsersCompanion.insert(
        name: 'Marcus Chen',
        email: 'marcus@example.com',
        role: const Value('worker'),
      ),
    );
  }

  // User queries
  Future<List<User>> getAllUsers() => select(users).get();

  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<User?> getUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  // Project queries
  Future<List<Project>> getAllProjects() => select(projects).get();

  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  Future<Project> getProjectById(int id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingle();

  Future<int> insertProject(ProjectsCompanion project) =>
      into(projects).insert(project);

  Future<bool> updateProject(ProjectsCompanion project) =>
      update(projects).replace(project);

  Future<int> deleteProject(int id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();

  // Project Assignment queries
  Future<List<Project>> getProjectsForUser(int userId) async {
    final query = select(projects).join([
      innerJoin(
        projectAssignments,
        projectAssignments.projectId.equalsExp(projects.id),
      ),
    ])..where(projectAssignments.userId.equals(userId));

    final results = await query.get();
    return results.map((row) => row.readTable(projects)).toList();
  }

  Stream<List<Project>> watchProjectsForUser(int userId) {
    final query = select(projects).join([
      innerJoin(
        projectAssignments,
        projectAssignments.projectId.equalsExp(projects.id),
      ),
    ])..where(projectAssignments.userId.equals(userId));

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(projects)).toList(),
    );
  }

  Future<void> assignUserToProject(int userId, int projectId) async {
    await into(projectAssignments).insert(
      ProjectAssignmentsCompanion.insert(projectId: projectId, userId: userId),
    );
  }

  // Receipt queries
  Future<List<Receipt>> getReceiptsForProject(int projectId) =>
      (select(receipts)..where((r) => r.projectId.equals(projectId))).get();

  Stream<List<Receipt>> watchReceiptsForProject(int projectId) =>
      (select(receipts)..where((r) => r.projectId.equals(projectId))).watch();

  Future<List<Receipt>> getPendingReceipts() =>
      (select(receipts)..where((r) => r.status.equals('pending'))).get();

  Stream<List<Receipt>> watchPendingReceipts() =>
      (select(receipts)..where((r) => r.status.equals('pending'))).watch();

  Future<List<Receipt>> getAllReceipts() => select(receipts).get();

  Stream<List<Receipt>> watchAllReceipts() => select(receipts).watch();

  Future<Receipt> getReceiptById(int id) =>
      (select(receipts)..where((r) => r.id.equals(id))).getSingle();

  Future<int> insertReceipt(ReceiptsCompanion receipt) =>
      into(receipts).insert(receipt);

  Future<void> updateReceiptStatus(
    int receiptId,
    String status, {
    int? verifiedById,
    String? notes,
  }) async {
    await (update(receipts)..where((r) => r.id.equals(receiptId))).write(
      ReceiptsCompanion(
        status: Value(status),
        verifiedById: verifiedById != null
            ? Value(verifiedById)
            : const Value.absent(),
        auditorNotes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteReceipt(int id) =>
      (delete(receipts)..where((r) => r.id.equals(id))).go();

  // Audit log queries
  Future<int> insertAuditLog(AuditLogsCompanion log) =>
      into(auditLogs).insert(log);

  Future<List<AuditLog>> getAuditLogsForReceipt(int receiptId) =>
      (select(auditLogs)..where((l) => l.receiptId.equals(receiptId))).get();

  // Aggregations
  Future<double> getTotalLiquidationForProject(int projectId) async {
    final projectReceipts = await getReceiptsForProject(projectId);
    double total = 0.0;
    for (final r in projectReceipts) {
      total += r.amount;
    }
    return total;
  }

  Future<double> getTotalLiquidationAllProjects() async {
    final allReceipts = await getAllReceipts();
    double total = 0.0;
    for (final r in allReceipts) {
      total += r.amount;
    }
    return total;
  }

  Future<int> getReceiptCountForProject(int projectId) async {
    final projectReceipts = await getReceiptsForProject(projectId);
    return projectReceipts.length;
  }

  Future<int> getPendingReceiptCount() async {
    final pending = await getPendingReceipts();
    return pending.length;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'liquidation_scanner.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
