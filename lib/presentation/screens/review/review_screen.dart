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
import '../../../data/services/ai_extraction_service.dart';
import 'package:drift/drift.dart' as drift;

class ReviewScreen extends ConsumerStatefulWidget {
  final String? imagePath;
  final int? projectId;

  const ReviewScreen({super.key, this.imagePath, this.projectId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isExtracting = true;
  double _aiConfidence = 0.0;
  String _extractionMethod = 'ml_kit';
  String _rawOcrText = '';
  String _parsedJson = '';
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
    _extractReceiptData();
  }

  Future<void> _extractReceiptData() async {
    if (widget.imagePath == null) {
      setState(() => _isExtracting = false);
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final result = await AiExtractionService.extractFromImage(
        widget.imagePath!,
      );

      if (mounted) {
        setState(() {
          if (result.vendor != null) {
            _vendorController.text = result.vendor!;
          }
          if (result.amount != null) {
            _amountController.text = result.amount!.toStringAsFixed(2);
          }
          if (result.date != null) {
            _selectedDate = result.date!;
            _dateController.text = DateFormat(
              'MMM dd, yyyy',
            ).format(result.date!);
          }
          if (result.category != null) {
            _categoryController.text = result.category!;
          }
          _aiConfidence = result.confidence;
          _extractionMethod = result.extractionMethod;
          _rawOcrText = result.rawText ?? '';
          _parsedJson = _buildParsedJson(result);
          _items.clear();
          for (final item in result.items) {
            _items.add({
              'name': item.name,
              'quantity': item.quantity ?? 1,
              'unitPrice': item.unitPrice ?? item.totalPrice ?? 0.0,
              'totalPrice':
                  item.totalPrice ??
                  (item.unitPrice ?? 0.0) * (item.quantity ?? 1),
            });
          }
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  String _buildParsedJson(dynamic result) {
    return '''
{
  "vendor": "${result.vendor ?? ''}",
  "amount": ${result.amount ?? 0},
  "date": "${result.date ?? ''}",
  "category": "${result.category ?? ''}",
  "confidence": ${result.confidence ?? 0},
  "items": [
${result.items.map((i) => '    {"name": "${i.name}", "quantity": ${i.quantity ?? 1}, "price": ${i.totalPrice ?? i.unitPrice ?? 0}}').join(',\n')}
  ]
}
''';
  }

  void _showDebugInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'OCR & Parsed Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const Text(
                      'Raw OCR Text:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _rawOcrText.isEmpty ? '(empty)' : _rawOcrText,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Parsed JSON:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _parsedJson.isEmpty ? '(empty)' : _parsedJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<int?> _saveReceipt() async {
    if (_formKey.currentState!.validate()) {
      final projectId = widget.projectId;

      if (projectId == null) {
        final projects = await ref.read(databaseProvider).getAllProjects();
        if (projects.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please create a project first')),
            );
          }
          return null;
        }
      }

      setState(() => _isLoading = true);

      try {
        final db = ref.read(databaseProvider);
        final selectedProjectId =
            projectId ?? (await db.getAllProjects()).first.id;
        final project = await db.getProjectById(selectedProjectId);

        String? lineItemsJson;
        if (_items.isNotEmpty) {
          lineItemsJson = jsonEncode(_items);
        }

        final receiptId = await db.insertReceipt(
          ReceiptsCompanion(
            projectId: drift.Value(selectedProjectId),
            vendor: drift.Value(_vendorController.text),
            amount: drift.Value(double.parse(_amountController.text)),
            receiptDate: drift.Value(_selectedDate),
            category: drift.Value(
              _categoryController.text.isEmpty
                  ? null
                  : _categoryController.text,
            ),
            notes: drift.Value(
              _notesController.text.isEmpty ? null : _notesController.text,
            ),
            imagePath: drift.Value(widget.imagePath),
            lineItems: lineItemsJson != null
                ? drift.Value(lineItemsJson)
                : const drift.Value.absent(),
            aiConfidence: drift.Value(_aiConfidence),
            status: const drift.Value('pending'),
          ),
        );

        await NotificationService.showNewReceiptNotification(
          vendor: _vendorController.text,
          amount: double.parse(_amountController.text),
          projectName: project.name,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt saved successfully!')),
          );
        }

        return receiptId;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving receipt: $e')));
        }
        return null;
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
    return null;
  }

  Future<void> _saveReceiptAndLog() async {
    final receiptId = await _saveReceipt();
    if (receiptId != null && mounted) {
      context.go('/projects');
    }
  }

  Future<void> _saveReceiptAndAudit() async {
    final receiptId = await _saveReceipt();
    if (receiptId != null && mounted) {
      context.push('/audit/$receiptId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imagePath != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surfaceContainerLow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Receipt Preview',
                  style: TextStyle(
                    color: AppColors.outline,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Extracted Data',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _vendorController,
                label: 'Vendor',
                icon: Icons.store_rounded,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Vendor is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountController,
                label: 'Total Amount',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Amount is required';
                  if (double.tryParse(value!) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: _buildTextField(
                        controller: _dateController,
                        label: 'Date',
                        icon: Icons.calendar_today_rounded,
                        enabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _categoryController,
                      label: 'Category',
                      icon: Icons.category_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: 'Notes (optional)',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 20),
              if (_isExtracting)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Extracting receipt data...',
                        style: TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _extractionMethod == 'gemini_nano'
                                  ? 'Gemini Nano (On-Device AI)'
                                  : 'ML Kit OCR',
                              style: TextStyle(
                                color: _extractionMethod == 'gemini_nano'
                                    ? Colors.green
                                    : AppColors.outline,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AI Confidence: ${(_aiConfidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The vendor and total amount have been extracted from the receipt.',
                              style: TextStyle(
                                color: AppColors.onSecondaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showDebugInfo(),
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('View OCR & Parsed Data'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _saveReceiptAndLog,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Confirm & Log'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveReceiptAndAudit,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fact_check_rounded),
                    label: Text(
                      _isLoading ? 'Processing...' : 'Confirm & Audit',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontWeight: maxLines == 1 ? FontWeight.w500 : FontWeight.normal,
            fontSize: maxLines == 1 ? 16 : 14,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.outline),
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No items extracted yet',
                style: TextStyle(color: AppColors.outline),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    item['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Qty: ${item['quantity']} × ₱${(item['unitPrice'] as double).toStringAsFixed(2)}',
                    style: TextStyle(color: AppColors.outline, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₱${(item['totalPrice'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.error,
                        onPressed: () {
                          setState(() {
                            _items.removeAt(index);
                          });
                          _updateTotalFromItems();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items: ${_items.length}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Total: ₱${_calculateItemsTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double _calculateItemsTotal() {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item['totalPrice'] as double),
    );
  }

  void _updateTotalFromItems() {
    final total = _calculateItemsTotal();
    if (total > 0) {
      _amountController.text = total.toStringAsFixed(2);
    }
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g., Hammer',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price',
                      prefixText: '₱ ',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final qty = int.tryParse(qtyController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0.0;

              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _items.add({
                    'name': name,
                    'quantity': qty,
                    'unitPrice': price,
                    'totalPrice': price * qty,
                  });
                });
                _updateTotalFromItems();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
