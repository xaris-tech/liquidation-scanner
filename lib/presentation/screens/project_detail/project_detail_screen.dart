import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';
import '../../../data/services/export_service.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  final Set<int> _selectedReceipts = {};
  bool _isSelectionMode = false;
  Future<Project>? _cachedProjectFuture;

  Future<Project> get _projectFuture {
    _cachedProjectFuture ??= ref
        .read(databaseProvider)
        .getProjectById(widget.projectId);
    return _cachedProjectFuture!;
  }

  void _debugLog(String message) {
    debugPrint(
      '[SelectionMode] $message | selectionMode: $_isSelectionMode | selectedCount: ${_selectedReceipts.length}',
    );
  }

  void _debugBuild(String where) {
    final stopwatch = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stopwatch.stop();
      debugPrint('[BuildTime] $where took ${stopwatch.elapsedMicroseconds}μs');
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final receiptsAsync = ref.watch(receiptsProvider(widget.projectId));

    debugPrint(
      '[ReceiptsProvider] isLoading: ${receiptsAsync.isLoading} | hasValue: ${receiptsAsync.hasValue} | valueOrNull: ${receiptsAsync.valueOrNull?.length}',
    );

    final buildStopwatch = Stopwatch()..start();
    debugPrint(
      '[Build] Building ProjectDetailScreen START | selectionMode: $_isSelectionMode | selected: $_selectedReceipts',
    );

    return FutureBuilder<Project>(
      future: _projectFuture,
      builder: (context, snapshot) {
        debugPrint(
          '[FutureBuilder] connectionState: ${snapshot.connectionState} | hasData: ${snapshot.hasData}',
        );
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Project not found')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                context.push('/scan', extra: {'projectId': widget.projectId}),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (_isSelectionMode) {
                      _debugLog('Back pressed - exiting selection mode');
                      setState(() {
                        _selectedReceipts.clear();
                        _isSelectionMode = false;
                      });
                    } else {
                      _debugLog('Back pressed - navigating back');
                      context.pop();
                    }
                  },
                ),
                actions: [
                  AnimatedOpacity(
                    opacity: _isSelectionMode ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: SizedBox(
                      width: 30,
                      child: Center(
                        child: Text(
                          '${_selectedReceipts.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isSelectionMode ? Icons.select_all : Icons.more_vert,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_isSelectionMode) {
                        _debugLog('Select All pressed');
                        final receipts = receiptsAsync.valueOrNull;
                        if (receipts == null || receipts.isEmpty) return;
                        setState(() {
                          if (_selectedReceipts.length == receipts.length) {
                            _selectedReceipts.clear();
                          } else {
                            _selectedReceipts.addAll(receipts.map((r) => r.id));
                          }
                        });
                      } else {
                        _showExportMenu(context, db, project);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isSelectionMode ? Icons.delete : Icons.filter_list,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_isSelectionMode) {
                        if (_selectedReceipts.isNotEmpty) {
                          _deleteSelectedReceipts();
                        }
                      } else {
                        _showFilterDialog(context);
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryContainer],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'ACTIVE PROJECT',
                              style: TextStyle(
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.name,
                              style: TextStyle(
                                color: AppColors.onPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Total Project Spending',
                                        style: TextStyle(
                                          color: AppColors.onPrimary.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                      receiptsAsync.when(
                                        data: (receipts) {
                                          final total = receipts.fold(
                                            0.0,
                                            (sum, r) => sum + r.amount,
                                          );
                                          return FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              NumberFormat.currency(
                                                symbol: '₱',
                                                decimalDigits: 2,
                                              ).format(total),
                                              style: TextStyle(
                                                color: AppColors.onPrimary,
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          );
                                        },
                                        loading: () => Text(
                                          '...',
                                          style: TextStyle(
                                            color: AppColors.onPrimary,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        error: (_, __) => Text(
                                          '₱0.00',
                                          style: TextStyle(
                                            color: AppColors.onPrimary,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    project.phase ?? 'PHASE 1',
                                    style: TextStyle(
                                      color: AppColors.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: receiptsAsync.when(
                    data: (receipts) {
                      final pendingCount = receipts
                          .where((r) => r.status == 'pending')
                          .length;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Logged Receipts',
                                  value: receipts.length.toString(),
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.pending_actions_rounded,
                                  label: 'Pending Audit',
                                  value: pendingCount.toString(),
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Logged Receipts',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: _isSelectionMode
                                    ? [
                                        IconButton(
                                          icon: const Icon(Icons.select_all),
                                          onPressed: () {
                                            _debugLog(
                                              'Header Select All pressed',
                                            );
                                            final r = receiptsAsync.valueOrNull;
                                            if (r == null || r.isEmpty) return;
                                            setState(() {
                                              if (_selectedReceipts.length ==
                                                  r.length) {
                                                _selectedReceipts.clear();
                                              } else {
                                                _selectedReceipts.addAll(
                                                  r.map((r) => r.id),
                                                );
                                              }
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _selectedReceipts.isEmpty
                                                ? Icons.delete_outline
                                                : Icons.delete,
                                            color: _selectedReceipts.isEmpty
                                                ? Colors.grey
                                                : Colors.red,
                                          ),
                                          onPressed: _selectedReceipts.isEmpty
                                              ? null
                                              : () {
                                                  _debugLog('Delete pressed');
                                                  _deleteSelectedReceipts();
                                                },
                                        ),
                                      ]
                                    : [
                                        IconButton(
                                          icon: const Icon(Icons.photo_library),
                                          onPressed: () => context.push(
                                            '/project/${widget.projectId}/gallery',
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.filter_list),
                                          onPressed: () =>
                                              _showFilterDialog(context),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ),
              receiptsAsync.when(
                data: (receipts) {
                  if (receipts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 64,
                              color: AppColors.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No receipts yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan your first receipt to start tracking',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/scan'),
                              icon: const Icon(Icons.document_scanner),
                              label: const Text('Scan Receipt'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final receipt = receipts[index];
                        return _ReceiptCard(
                          key: ValueKey(receipt.id),
                          receipt: receipt,
                          isSelected: _selectedReceipts.contains(receipt.id),
                          isSelectionMode: _isSelectionMode,
                          onLongPress: () {
                            _debugLog('Long press on receipt ${receipt.id}');
                            setState(() {
                              _isSelectionMode = true;
                              _selectedReceipts.add(receipt.id);
                            });
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              _debugLog('Tap on receipt ${receipt.id}');
                              setState(() {
                                if (_selectedReceipts.contains(receipt.id)) {
                                  _selectedReceipts.remove(receipt.id);
                                  if (_selectedReceipts.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  _selectedReceipts.add(receipt.id);
                                }
                              });
                            } else {
                              context.push('/audit/${receipt.id}');
                            }
                          },
                        );
                      }, childCount: receipts.length),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $error')),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
        buildStopwatch.stop();
        debugPrint(
          '[Build] Building ProjectDetailScreen END | took ${buildStopwatch.elapsedMicroseconds}μs',
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Receipts',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.list, color: AppColors.primary),
              title: const Text('All Receipts'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.green),
              title: const Text('Verified'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('Pending'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Rejected'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportMenu(BuildContext context, AppDatabase db, Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                final receipts = await db.getReceiptsForProject(
                  widget.projectId,
                );
                final file = await ExportService.generateProjectReportPdf(
                  project,
                  receipts,
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF saved: ${file.path}')),
                  );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export CSV'),
              onTap: () async {
                Navigator.pop(ctx);
                final receipts = await db.getReceiptsForProject(
                  widget.projectId,
                );
                final file = await ExportService.generateCsvExport(
                  project,
                  receipts,
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('CSV saved: ${file.path}')),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedReceipts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipts'),
        content: Text(
          'Are you sure you want to delete ${_selectedReceipts.length} receipt(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _debugLog(
        'Delete confirmed - deleting ${_selectedReceipts.length} receipts',
      );
      final db = ref.read(databaseProvider);
      final count = _selectedReceipts.length;
      for (final id in _selectedReceipts) {
        await db.deleteReceipt(id);
      }
      setState(() {
        _selectedReceipts.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count receipts deleted')));
      }
    } else {
      _debugLog('Delete cancelled');
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _ReceiptCard({
    super.key,
    required this.receipt,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppColors.primary : AppColors.outline,
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.store_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.vendor,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(receipt.receiptDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(receipt.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: receipt.status == 'verified'
                        ? AppColors.primaryFixed
                        : AppColors.tertiaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        receipt.status == 'verified'
                            ? Icons.verified_rounded
                            : Icons.schedule_rounded,
                        size: 12,
                        color: receipt.status == 'verified'
                            ? AppColors.onPrimaryFixedVariant
                            : AppColors.onTertiaryFixedVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        receipt.status == 'verified' ? 'Verified' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: receipt.status == 'verified'
                              ? AppColors.onPrimaryFixedVariant
                              : AppColors.onTertiaryFixedVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
