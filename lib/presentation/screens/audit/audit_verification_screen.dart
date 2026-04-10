import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_provider.dart';
import '../../../data/database/app_database.dart';
import '../../../data/services/notification_service.dart';
import 'package:drift/drift.dart' as drift;

class AuditVerificationScreen extends ConsumerStatefulWidget {
  final int receiptId;

  const AuditVerificationScreen({super.key, required this.receiptId});

  @override
  ConsumerState<AuditVerificationScreen> createState() =>
      _AuditVerificationScreenState();
}

class _AuditVerificationScreenState
    extends ConsumerState<AuditVerificationScreen> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<Receipt>(
      future: db.getReceiptById(widget.receiptId),
      builder: (context, receiptSnapshot) {
        if (receiptSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final receipt = receiptSnapshot.data;
        if (receipt == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Receipt not found')),
          );
        }

        return FutureBuilder<Project>(
          future: db.getProjectById(receipt.projectId),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final project = projectSnapshot.data!;

            return Scaffold(
              backgroundColor: AppColors.surface,
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 120,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primaryContainer,
                            ],
                          ),
                        ),
                      ),
                      titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                      title: Text(
                        'Audit Receipt',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _ContextHeader(project: project, receipt: receipt),
                          const SizedBox(height: 20),
                          _ReceiptImageCard(receipt: receipt),
                          const SizedBox(height: 20),
                          _AISummaryCard(receipt: receipt),
                          const SizedBox(height: 24),
                          _AuditActions(
                            isProcessing: _isProcessing,
                            onVerify: () => _verifyReceipt(receipt),
                            onReject: () => _rejectReceipt(receipt),
                          ),
                          const SizedBox(height: 20),
                          _AuditorNotes(controller: _notesController),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _verifyReceipt(Receipt receipt) async {
    setState(() => _isProcessing = true);
    try {
      final authState = ref.read(authStateProvider);
      final db = ref.read(databaseProvider);

      await db.updateReceiptStatus(
        receipt.id,
        'verified',
        verifiedById: authState.user?.id,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await db.insertAuditLog(
        AuditLogsCompanion.insert(
          receiptId: receipt.id,
          userId: authState.user?.id ?? 1,
          action: 'verified',
          notes: drift.Value(
            _notesController.text.isNotEmpty ? _notesController.text : null,
          ),
        ),
      );

      await NotificationService.showReceiptVerifiedNotification(
        vendor: receipt.vendor,
        amount: receipt.amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt verified successfully!')),
        );
        context.go('/projects');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectReceipt(Receipt receipt) async {
    setState(() => _isProcessing = true);
    try {
      final authState = ref.read(authStateProvider);
      final db = ref.read(databaseProvider);

      await db.updateReceiptStatus(
        receipt.id,
        'rejected',
        verifiedById: authState.user?.id,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await db.insertAuditLog(
        AuditLogsCompanion.insert(
          receiptId: receipt.id,
          userId: authState.user?.id ?? 1,
          action: 'rejected',
          notes: drift.Value(
            _notesController.text.isNotEmpty ? _notesController.text : null,
          ),
        ),
      );

      await NotificationService.showReceiptRejectedNotification(
        vendor: receipt.vendor,
        amount: receipt.amount,
        reason: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Receipt rejected')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class _ContextHeader extends ConsumerWidget {
  final Project project;
  final Receipt receipt;

  const _ContextHeader({required this.project, required this.receipt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT PROJECT',
                        style: TextStyle(
                          color: AppColors.outline,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (project.location != null)
                        Text(
                          project.location!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            onPressed: () => _showProjectSelector(context, ref),
          ),
        ),
      ],
    );
  }

  void _showProjectSelector(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final projects = await db.getAllProjects();
    final rec = receipt;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectSelectorSheet(
        projects: projects,
        currentReceipt: rec,
        onSelect: (project) async {
          await db.updateReceiptProject(rec.id, project.id);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            Navigator.pop(context);
            context.push('/audit/${rec.id}');
          }
        },
      ),
    );
  }
}

class _ProjectSelectorSheet extends StatelessWidget {
  final List<Project> projects;
  final Receipt currentReceipt;
  final Function(Project) onSelect;

  const _ProjectSelectorSheet({
    required this.projects,
    required this.currentReceipt,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Move to Project',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: projects.length,
              itemBuilder: (listCtx, index) {
                final p = projects[index];
                final isSelected = p.id == currentReceipt.projectId;

                return ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: isSelected ? AppColors.primary : AppColors.outline,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: p.location != null ? Text(p.location!) : null,
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: isSelected ? null : () => onSelect(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptImageCard extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptImageCard({required this.receipt});

  static void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Original Capture',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (receipt.imagePath != null)
            GestureDetector(
              onTap: () => _showFullScreenImage(context, receipt.imagePath!),
              child: Stack(
                children: [
                  ClipRRect(
                    child: Image.file(
                      File(receipt.imagePath!),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              color: AppColors.surfaceContainerLow,
              child: Icon(
                Icons.receipt_long_rounded,
                size: 64,
                color: AppColors.outlineVariant,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded: ${DateFormat('MMM dd, yyyy • HH:mm').format(receipt.createdAt)}',
                  style: TextStyle(
                    color: AppColors.outline,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Row(
                  children: [
                    _StatusBadge(label: 'Legible', color: Colors.green),
                    const SizedBox(width: 8),
                    _StatusBadge(label: 'Authentic', color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AISummaryCard extends StatelessWidget {
  final Receipt receipt;

  const _AISummaryCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Data Extraction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Confidence Score: ${receipt.aiConfidence != null ? "${(receipt.aiConfidence! * 100).toStringAsFixed(1)}%" : "N/A"}',
                    style: TextStyle(color: AppColors.outline, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.smart_toy_rounded, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DataField(label: 'Merchant', value: receipt.vendor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DataField(
                  label: 'Date',
                  value: DateFormat('MMM dd, yyyy').format(receipt.receiptDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (receipt.category != null)
            _DataField(label: 'Category', value: receipt.category!),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL AMOUNT',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  currencyFormat.format(receipt.amount),
                  style: TextStyle(
                    color: AppColors.onPrimaryFixed,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (receipt.lineItems != null && receipt.lineItems!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _LineItemsSection(lineItemsJson: receipt.lineItems!),
          ],
        ],
      ),
    );
  }
}

class _LineItemsSection extends StatelessWidget {
  final String lineItemsJson;

  const _LineItemsSection({required this.lineItemsJson});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    List<dynamic> items = [];
    try {
      items = jsonDecode(lineItemsJson) as List<dynamic>;
    } catch (_) {
      return const SizedBox();
    }

    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXTRACTED ITEMS',
          style: TextStyle(
            color: AppColors.outline,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String? ?? 'Unknown Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty: ${item['quantity']} × ${currencyFormat.format((item['unitPrice'] as num?)?.toDouble() ?? 0)}',
                            style: TextStyle(
                              color: AppColors.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormat.format(
                        (item['totalPrice'] as num?)?.toDouble() ?? 0,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DataField extends StatelessWidget {
  final String label;
  final String value;

  const _DataField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.outline,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AuditActions extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const _AuditActions({
    required this.isProcessing,
    required this.onVerify,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isProcessing ? null : onReject,
            icon: const Icon(Icons.close_rounded),
            label: const Text('REJECT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : onVerify,
            icon: isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(isProcessing ? 'Processing...' : 'VERIFY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditorNotes extends StatelessWidget {
  final TextEditingController controller;

  const _AuditorNotes({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AUDITOR REMARKS (OPTIONAL)',
            style: TextStyle(
              color: AppColors.outline,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note about this verification...',
              hintStyle: TextStyle(
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
