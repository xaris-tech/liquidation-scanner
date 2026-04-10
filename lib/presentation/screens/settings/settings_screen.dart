import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/supabase_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AppPreferencesSection(
                    onNotificationsTap: () =>
                        _showComingSoon(context, 'Notifications'),
                    onBackupTap: () =>
                        _showComingSoon(context, 'Sync & Backup'),
                    onStorageTap: () => _showStorageInfo(context),
                  ),
                  const SizedBox(height: 24),
                  _AboutSection(
                    onAboutTap: () => _showAboutDialog(context),
                    onHelpTap: () => _showHelpSupportDialog(context),
                    onPrivacyTap: () => _showPrivacyPolicy(context),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.document_scanner_rounded,
                            color: AppColors.onPrimary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Liquidation Scanner',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo(BuildContext context) async {
    final db = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${db.path}/receipts');
    int fileCount = 0;
    int totalSize = 0;

    if (await receiptsDir.exists()) {
      final files = receiptsDir.listSync();
      fileCount = files.length;
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
    }

    final sizeInMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage'),
          content: Text(
            'Receipt images: $fileCount files\n'
            'Total size: $sizeInMB MB\n\n'
            'Images are stored in the app\'s documents folder and saved to your gallery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liquidation Scanner',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text(
              'Scan, track, and manage liquidation receipts on-the-go. '
              'Features include document scanning with edge detection, '
              'AI-powered receipt data extraction, and export capabilities.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _FeedbackDialog());
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Liquidation Scanner Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'Last updated: April 2026',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Data Collection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'This app stores all data locally on your device. We do not collect, transmit, or store any personal information on external servers. All receipt images, project data, and user information remain exclusively on your device.',
              ),
              const SizedBox(height: 12),
              const Text(
                '2. Image Storage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Receipt images are stored in the app\'s private documents folder and can optionally be saved to your device\'s photo gallery. Images are not uploaded to any external service.',
              ),
              const SizedBox(height: 12),
              const Text(
                '3. Permissions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'The app requires camera access to scan receipts, and storage access to save receipt images. These permissions are used solely for the app\'s core functionality.',
              ),
              const SizedBox(height: 12),
              const Text(
                '4. Third-Party Services',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'This app uses local-only storage. No data is shared with third parties. The optional AI-powered text recognition processes all data on-device.',
              ),
              const SizedBox(height: 12),
              const Text(
                '5. Data Security',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'All data stored locally on your device is protected by your device\'s built-in security features. We recommend enabling device encryption and using secure lock methods.',
              ),
              const SizedBox(height: 12),
              const Text(
                '6. Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'For privacy concerns, please contact: rajienomoto@gmail.com',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedType = 'bug';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.submitFeedback(
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Help & Support'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submit your feedback, bug reports, or suggestions:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'bug',
                    label: Text('Bug'),
                    icon: Icon(Icons.bug_report_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: 'suggestion',
                    label: Text('Suggestion'),
                    icon: Icon(Icons.lightbulb_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: 'ticket',
                    label: Text('Ticket'),
                    icon: Icon(Icons.confirmation_number_rounded, size: 18),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (selection) {
                  setState(() => _selectedType = selection.first);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Brief summary',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your issue or suggestion in detail',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'your@email.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback will be saved to our cloud database for tracking.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitFeedback,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _AppPreferencesSection extends StatelessWidget {
  final VoidCallback onNotificationsTap;
  final VoidCallback onBackupTap;
  final VoidCallback onStorageTap;

  const _AppPreferencesSection({
    required this.onNotificationsTap,
    required this.onBackupTap,
    required this.onStorageTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'App Preferences',
      children: [
        _SettingsTile(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Manage notification settings',
          onTap: onNotificationsTap,
        ),
        _SettingsTile(
          icon: Icons.cloud_sync_rounded,
          title: 'Sync & Backup',
          subtitle: 'Cloud sync settings',
          onTap: onBackupTap,
        ),
        _SettingsTile(
          icon: Icons.storage_rounded,
          title: 'Storage',
          subtitle: 'Manage local storage',
          onTap: onStorageTap,
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final VoidCallback onAboutTap;
  final VoidCallback onHelpTap;
  final VoidCallback onPrivacyTap;

  const _AboutSection({
    required this.onAboutTap,
    required this.onHelpTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'About',
      children: [
        _SettingsTile(
          icon: Icons.info_rounded,
          title: 'About App',
          subtitle: 'Version 1.0.0',
          onTap: onAboutTap,
        ),
        _SettingsTile(
          icon: Icons.help_rounded,
          title: 'Help & Support',
          subtitle: 'Send suggestions and tickets for bug fixes',
          onTap: onHelpTap,
          isHighlighted: true,
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          subtitle: 'View privacy policy',
          onTap: onPrivacyTap,
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isHighlighted;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.isHighlighted = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_SettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isHighlighted ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.isHighlighted
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : widget.iconColor?.withValues(alpha: 0.1) ??
                                AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isHighlighted
                          ? AppColors.primary
                          : (widget.iconColor ?? AppColors.primary),
                      size: 22,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.isHighlighted
                                    ? AppColors.primary
                                    : null,
                              ),
                        ),
                      ),
                      if (widget.isHighlighted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEEDBACK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: widget.isHighlighted ? AppColors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: widget.isHighlighted
                  ? AppColors.primary
                  : AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}
