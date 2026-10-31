import '../../services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database_helper.dart';
import '../../services/gemini_service.dart';
import '../../core/theme/app_theme.dart';
import 'debug_screen.dart';
import 'import_sms_screen.dart';
import 'import_file_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final tp = context.read<TransactionProvider>();
      final file = await BackupService.instance.exportFullBackup(tp.allOtps);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Backup Exported!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All transactions & OTPs successfully backed up to JSON:'),
                const SizedBox(height: 10),
                SelectableText(
                  file.path,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('Transfer this file to your new device and tap "Restore / Import Full Backup".', style: TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: ' + e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final stats = await BackupService.instance.importFullBackup(path);
        if (context.mounted) {
          final tp = context.read<TransactionProvider>();
          await tp.loadTransactions();
          final count = stats['transactions'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup Restored! Imported ' + count.toString() + ' transactions.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: ' + e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  bool _isSyncing = false;

  Future<void> _showSyncOptions() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sync SMS with AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: AppTheme.primaryColor),
              ),
              title: const Text('Sync Last 30 Days'),
              subtitle: const Text('Fast sync: analyzes recent SMS messages with AI'),
              onTap: () {
                Navigator.pop(context);
                _syncSMS(limit: 500);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.all_inclusive_rounded, color: AppTheme.secondaryColor),
              ),
              title: const Text('Sync All Time'),
              subtitle: const Text('Deep scan: analyzes all bank SMS history'),
              onTap: () {
                Navigator.pop(context);
                _syncSMS();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncSMS({int? limit}) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final transactionProvider = context.read<TransactionProvider>();
      await transactionProvider.syncFromSMS(limit: limit);

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SMS sync complete! Found ${transactionProvider.allTransactions.length} total transactions',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Consumer<SettingsProvider>(
          builder: (context, provider, child) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings & Studio',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Appearance, AI engine, alerts & data tools',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Appearance & Theme Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildAppearanceCard(provider, isDark),
                  ),
                ),

                // AI Intelligence Engine Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildAiAssistantCard(provider, isDark),
                  ),
                ),

                // Preferences & Budget Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildPreferencesCard(provider, isDark),
                  ),
                ),

                // Data Management Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildDataManagementCard(isDark),
                  ),
                ),

                // Developer Tools Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildDevToolsCard(isDark),
                  ),
                ),

                // Danger Zone Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildDangerZoneCard(isDark),
                  ),
                ),

                // App Info Footer
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'FinTracker v1.0.0 (Pro Release)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI Financial Intelligence • Automatic Theme Support',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom padding for floating island tab bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 110),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(SettingsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance & Theme',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Automatic system match, light, or dark mode',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 3-way Theme Selection Pills
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildThemeOption(
                  title: 'Auto (System)',
                  icon: Icons.brightness_auto_rounded,
                  mode: ThemeMode.system,
                  currentMode: provider.themeMode,
                  onSelect: () => provider.setThemeMode(ThemeMode.system),
                  isDark: isDark,
                ),
                _buildThemeOption(
                  title: 'Light',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  currentMode: provider.themeMode,
                  onSelect: () => provider.setThemeMode(ThemeMode.light),
                  isDark: isDark,
                ),
                _buildThemeOption(
                  title: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  currentMode: provider.themeMode,
                  onSelect: () => provider.setThemeMode(ThemeMode.dark),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required VoidCallback onSelect,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistantCard(SettingsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini AI Engine',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        provider.hasCustomGeminiKey
                            ? 'Custom API Key Active'
                            : 'Camspot Credentials Active',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showAiConfigDialog(context, provider),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Config', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Extracts transaction amounts, determines credit vs. debit financial intent, flags waste of money, and extracts verification OTPs in real time.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(SettingsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Alerts & Notifications',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Alert when a new transaction SMS is recorded',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: provider.notificationsEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => provider.setNotificationsEnabled(val),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budget Limit',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      provider.monthlyBudget != null
                          ? '₹${provider.monthlyBudget!.toStringAsFixed(0)} set'
                          : 'No budget target set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.monthlyBudget != null
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showBudgetDialog(context, provider),
                child: Text(provider.monthlyBudget != null ? 'Edit' : 'Set'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Sync & Management',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.sync_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Re-Sync SMS with AI',
            subtitle: 'Re-categorize and sync bank messages',
            trailing: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _isSyncing ? null : _showSyncOptions,
            isDark: isDark,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            icon: Icons.paste_rounded,
            iconColor: Colors.teal,
            title: 'Paste & Test SMS',
            subtitle: 'Paste any transaction SMS to test parser',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportSmsScreen()),
              );
            },
            isDark: isDark,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            icon: Icons.file_upload_outlined,
            iconColor: Colors.orange,
            title: 'Import CSV / XML Backup',
            subtitle: 'Restore SMS data from file exports',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportFileScreen()),
              );
            },
            isDark: isDark,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            icon: Icons.backup_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Export Full Backup (JSON)',
            subtitle: 'Backup all data to JSON to continue on new device',
            trailing: const Icon(Icons.download_rounded, color: Color(0xFF10B981)),
            onTap: () => _exportBackup(context),
            isDark: isDark,
          ),
          const Divider(height: 16),
          _buildSettingsTile(
            icon: Icons.settings_backup_restore_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Restore / Import Full Backup',
            subtitle: 'Restore JSON backup from previous phone',
            trailing: const Icon(Icons.upload_rounded, color: Color(0xFF6366F1)),
            onTap: () => _importBackup(context),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDevToolsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnostics & Developer Tools',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.bug_report_rounded,
            iconColor: Colors.amber[700]!,
            title: 'Diagnostics Screen',
            subtitle: 'SMS stream inspect, DB query stats & parser logs',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugScreen()),
              );
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.delete_forever_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Clear All Financial Data',
            subtitle: 'Permanently purge local database transactions & OTPs',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444)),
            onTap: () => _showClearDataDialog(context),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showAiConfigDialog(BuildContext context, SettingsProvider provider) {
    final controller = TextEditingController(
      text: provider.hasCustomGeminiKey ? provider.geminiApiKey : '',
    );
    bool testing = false;
    String? testResult;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('AI Assistant Config'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FinTracker uses Gemini AI to extract exact amounts, categories, and merchants from bank SMS.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: provider.hasCustomGeminiKey
                      ? 'Custom key configured'
                      : 'Default Camspot key active',
                  border: const OutlineInputBorder(),
                  suffixIcon: provider.hasCustomGeminiKey
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            setDialogState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (testResult != null)
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: testResult!.startsWith('Success') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: testing
                    ? null
                    : () async {
                        setDialogState(() {
                          testing = true;
                          testResult = 'Testing connection...';
                        });
                        final keyToTest = controller.text.trim().isNotEmpty
                            ? controller.text.trim()
                            : provider.geminiApiKey;
                        final ok = await GeminiService.instance.testConnection(apiKey: keyToTest);
                        setDialogState(() {
                          testing = false;
                          testResult = ok
                              ? 'Success: Gemini AI connection verified!'
                              : 'Notice: Key tested. Fallback models and enhanced parser active.';
                        });
                      },
                icon: testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Test Connection'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (provider.hasCustomGeminiKey)
              TextButton(
                onPressed: () {
                  provider.setGeminiApiKey(null);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to Camspot default credentials')),
                  );
                },
                child: const Text('Reset Default'),
              ),
            TextButton(
              onPressed: () {
                final key = controller.text.trim();
                provider.setGeminiApiKey(key.isNotEmpty ? key : null);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI Assistant configuration saved')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, SettingsProvider provider) {
    final controller = TextEditingController(
      text: provider.monthlyBudget?.toStringAsFixed(0) ?? '',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final budget = double.tryParse(controller.text);
              provider.setMonthlyBudget(budget);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all transactions and captured OTPs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final transactionProvider = context.read<TransactionProvider>();
              await DatabaseHelper.instance.clearAllData();
              await transactionProvider.loadTransactions();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All financial data cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
