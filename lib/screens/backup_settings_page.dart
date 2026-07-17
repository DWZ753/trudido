// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_backup_service.dart';
import '../services/files_channel.dart';
import '../services/markdown_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import '../providers/app_providers.dart';
import '../providers/notes_providers.dart';
import '../repositories/note_folder_repository.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  @override
  void initState() {
    super.initState();

    FilesChannel.instance.setImportCallbacks(
      onComplete: (message) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        );
        // Trigger refresh after successful import
        _refreshProviders();
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      },
      onRefreshNeeded: () {
        _refreshProviders();
      },
      onPasswordRequired: () => _showPasswordInputDialog(
        title: '加密备份',
        message:
            '此备份受密码保护。请输入密码进行解密：',
      ),
    );
  }

  /// Shows a password input dialog and returns the entered password
  Future<String?> _showPasswordInputDialog({
    required String title,
    required String message,
    bool isConfirm = false,
  }) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '密码',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
                ),
              ),
              if (isConfirm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    labelText: '确认密码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (isConfirm && controller.text != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('密码不匹配'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(controller.text);
              },
              child: Text(isConfirm ? '加密' : '解密'),
            ),
          ],
        ),
      ),
    );
  }

  /// Refreshes all providers after import to ensure UI shows updated data
  Future<void> _refreshProviders() async {
    if (!mounted) return;

    try {
      debugPrint('[BackupSettings] Starting provider refresh after import...');

      // Invalidate and refresh available providers
      ref.invalidate(tasksProvider);
      ref.invalidate(preferencesStateProvider);
      ref.invalidate(notesProvider);
      ref.invalidate(noteFoldersProvider);

      // Force rebuild by reading providers
      ref.read(tasksProvider.notifier).refresh();
      ref.read(preferencesStateProvider);
      ref.read(notesProvider.notifier).refresh();
      ref.read(noteFoldersProvider.notifier).refresh();

      // Wait a moment for providers to refresh
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('[BackupSettings] Provider refresh completed');

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            '数据已刷新 - 你导入的任务、笔记和文件夹现在应该可见！',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[BackupSettings] Error during provider refresh: $e');
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('刷新失败：$e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showAutoBackupSetupDialog() async {
    // Load current settings
    final isCurrentlyEnabled = await AutoBackupService.instance
        .isAutoBackupScheduled();
    int selectedInterval = 24; // Default: daily
    bool requiresCharging = false;
    final currentPassword = StorageService.getAutoBackupPassword();
    final passwordController = TextEditingController(
      text: currentPassword ?? '',
    );
    final confirmPasswordController = TextEditingController(
      text: currentPassword ?? '',
    );
    bool isEnabled = isCurrentlyEnabled;
    bool obscurePassword = true;

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('自动备份设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enable/Disable toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用自动备份'),
                  subtitle: Text(
                    isEnabled
                        ? '备份自动运行'
                        : '备份已禁用',
                  ),
                  value: isEnabled,
                  onChanged: (value) => setState(() => isEnabled = value),
                ),
                SpacingGap.gapV8,

                // Settings (only shown when enabled)
                AnimatedOpacity(
                  opacity: isEnabled ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !isEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info about backup location
                        Container(
                          padding: SpacingEdgeInsets.insets12,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: SpacingBorderRadius.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              SpacingGap.gapH8,
                              Expanded(
                                child: Text(
                                  'Backups are saved to Android/data/com.trudido.app/files/AutoBackups/',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SpacingGap.gapV16,

                        // Backup Frequency
                        DropdownButtonFormField<int>(
                          initialValue: selectedInterval,
                          decoration: const InputDecoration(
                            labelText: '备份频率',
                            border: OutlineInputBorder(),
                          ),
                          items: AutoBackupService.backupIntervals.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.value,
                                  child: Text(entry.key),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedInterval = value);
                            }
                          },
                        ),
                        SpacingGap.gapV12,

                        // Charging condition
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('仅在充电时'),
                          subtitle: const Text('节省电池电量'),
                          value: requiresCharging,
                          onChanged: (value) {
                            setState(() => requiresCharging = value ?? false);
                          },
                        ),
                        SpacingGap.gapV16,

                        // Password section
                        Text(
                          '加密（可选）',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SpacingGap.gapV8,
                        Text(
                          '设置密码以加密备份。留空表示不加密。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SpacingGap.gapV12,
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: '密码',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        SpacingGap.gapV12,
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscurePassword,
                          decoration: const InputDecoration(
                            labelText: '确认密码',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                // Validate passwords match if set
                if (passwordController.text.isNotEmpty &&
                    passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('密码不匹配'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'enabled': isEnabled,
                  'interval': selectedInterval,
                  'requiresCharging': requiresCharging,
                  'password': passwordController.text,
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return; // Cancelled

    final enabled = result['enabled'] as bool;
    final interval = result['interval'] as int;
    final charging = result['requiresCharging'] as bool;
    final password = result['password'] as String;

    // Save password setting
    if (password.isEmpty) {
      await StorageService.setAutoBackupPassword(null);
    } else {
      await StorageService.setAutoBackupPassword(password);
    }

    if (enabled) {
      final success = await AutoBackupService.instance.scheduleAutoBackup(
        intervalHours: interval,
        requiresCharging: charging,
      );

      // Cache backup data immediately
      await AutoBackupService.instance.cacheBackupData();

      if (!mounted) return;

      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto backup enabled! Backing up ${AutoBackupService.getBackupFrequencyDescription(interval).toLowerCase()}${password.isNotEmpty ? ' (encrypted)' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('启用自动备份失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await AutoBackupService.instance.cancelAutoBackup();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自动备份已禁用'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showAutoBackupImportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SpacingGap.gapH16,
            Text('正在加载备份...'),
          ],
        ),
      ),
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final backups = await AutoBackupService.instance.listAutoBackups();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (backups.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('未找到自动备份'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      AutoBackupFile? selectedBackup;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('导入自动备份'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const Text('选择要导入的备份：'),
                  SpacingGap.gapV16,
                  Expanded(
                    child: ListView.builder(
                      itemCount: backups.length,
                      itemBuilder: (context, index) {
                        final backup = backups[index];
                        return RadioListTile<AutoBackupFile>(
                          value: backup,
                          // ignore: deprecated_member_use
                          groupValue: selectedBackup,
                          // ignore: deprecated_member_use
                          onChanged: (value) {
                            setState(() => selectedBackup = value);
                          },
                          title: Text(backup.filename),
                          subtitle: Text(
                            '${backup.formattedDate} • ${backup.formattedSize}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ExpressiveTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ExpressiveElevatedButton(
                onPressed: selectedBackup != null
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('导入'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && selectedBackup != null) {
        if (!mounted) return;
        // Confirm import
        final reallyImport = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认导入'),
            content: Text(
              '导入"${selectedBackup!.filename}"？\n\n'
              '这将用备份替换你当前的数据。',
            ),
            actions: [
              ExpressiveTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ExpressiveElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ExpressiveElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('导入'),
              ),
            ],
          ),
        );

        if (reallyImport == true) {
          // Perform the import
          final success = await AutoBackupService.instance.importAutoBackup(
            selectedBackup!.filename,
          );
          if (!mounted) return;

          final scaffoldMessenger = ScaffoldMessenger.of(context);
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('备份导入成功！'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshProviders();
          } else {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('导入备份失败'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog if still open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载备份出错：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showExportLocationDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择导出位置'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('你想将备份保存到哪里？')],
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('取消'),
          ),
          ExpressiveOutlinedButton(
            onPressed: () => Navigator.of(context).pop('custom'),
            child: const Text('自定义文件夹'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('picker'),
            child: const Text('选择位置'),
          ),
        ],
      ),
    );

    if (choice == 'custom') {
      await _performCustomFolderExport();
    } else if (choice == 'picker') {
      await _performTraditionalExport();
    }
  }

  Future<void> _performCustomFolderExport() async {
    // Ask user if they want to encrypt the backup
    final password = await _askForExportPassword();
    if (password == null) return; // User cancelled the password dialog

    // Export to the user's chosen backup folder
    try {
      await FilesChannel.instance.startExport(
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            password.isEmpty
                ? '导出已保存到备份文件夹！'
                : '加密导出已保存到备份文件夹！',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performTraditionalExport() async {
    // Ask user if they want to encrypt the backup
    final password = await _askForExportPassword();
    if (password == null) return; // User cancelled the password dialog

    // Use the traditional file picker
    try {
      await FilesChannel.instance.startExport(
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            password.isEmpty
                ? '导出已启动 - 选择保存位置'
                : '加密导出已启动 - 选择保存位置',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Asks user if they want to protect the backup with a password
  /// Returns empty string for no protection, password string for encryption, null if cancelled
  Future<String?> _askForExportPassword() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保护备份？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('是否要用密码加密此备份？'),
            SizedBox(height: 12),
            Text(
              '• 如果你有保险库/锁定文件夹，建议加密\n'
              '• 如果备份文件被他人访问，可保护你的数据\n'
              '• 如果忘记密码，备份将无法恢复',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(''), // No password
            child: const Text('不保护'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop('SET_PASSWORD'), // Signal to show password dialog
            child: const Text('设置密码'),
          ),
        ],
      ),
    );

    if (choice == null) return null; // Cancelled
    if (choice == '') return ''; // No protection

    // User wants to set a password
    return await _showPasswordInputDialog(
      title: '设置备份密码',
      message: '输入密码以加密备份：',
      isConfirm: true,
    );
  }

  Future<void> _exportNotesToMarkdown() async {
    try {
      final success = await MarkdownExportService.exportNotesToFiles();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('笔记已导出为 markdown 文件！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('没有笔记可导出或导出已取消'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importNotesFromMarkdown() async {
    try {
      final result = await MarkdownExportService.importNotesFromFiles();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (result.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh notes provider to show imported notes
        ref.read(notesProvider.notifier).refresh();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAllDataToPdf() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在生成 PDF 导出...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final success = await PdfExportService.exportAllDataToPdf();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'PDF 导出就绪！选择保存或分享位置。',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('没有数据可导出或导出已取消'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 导出失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('备份与数据')),
      body: ListView(
        children: [
          // Header description
          Padding(
            padding: SpacingEdgeInsets.insets16,
            child: Text(
              '备份和恢复你的任务、分类、笔记和设置。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Backup Location Section
          _buildSectionHeader(context, '备份位置'),
          FutureBuilder<String?>(
            future: AutoBackupService.instance.getCustomBackupFolder(),
            builder: (context, snapshot) {
              final customFolder = snapshot.data;
              final hasCustomFolder = customFolder != null;

              return ListTile(
                leading: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('存储位置'),
                subtitle: Text(
                  hasCustomFolder
                      ? '已选择自定义文件夹'
                      : '默认应用文件夹',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCustomFolder)
                      ExpressiveIconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: '重置为默认',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await AutoBackupService.instance
                              .clearCustomBackupFolder();
                          if (!mounted) return;
                          if (success) {
                            setState(() {});
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('已恢复为默认文件夹'),
                              ),
                            );
                          }
                        },
                      ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () async {
                  final success = await AutoBackupService.instance
                      .chooseBackupFolder();
                  if (!mounted) return;
                  if (success) {
                    setState(() {});
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('备份文件夹已成功更新'),
                      ),
                    );
                  }
                },
              );
            },
          ),

          // Export Section
          _buildSectionHeader(context, '导出'),
          ListTile(
            leading: Icon(
              Icons.upload_file_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('导出全部数据（JSON）'),
            subtitle: const Text('保存任务、笔记和设置'),
            onTap: () async {
              final customFolder = await AutoBackupService.instance
                  .getCustomBackupFolder();
              if (customFolder != null) {
                await _showExportLocationDialog();
              } else {
                await _performTraditionalExport();
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.picture_as_pdf_outlined,
              color: colorScheme.error,
            ),
            title: const Text('导出为 PDF'),
            subtitle: const Text('创建所有数据的可读文档'),
            onTap: _exportAllDataToPdf,
          ),
          ListTile(
            leading: Icon(Icons.note_outlined, color: colorScheme.tertiary),
            title: const Text('导出笔记（Markdown）'),
            subtitle: const Text('将笔记保存为 .md 文件'),
            onTap: _exportNotesToMarkdown,
          ),

          // Import Section
          _buildSectionHeader(context, '导入'),
          ListTile(
            leading: Icon(Icons.download_outlined, color: colorScheme.primary),
            title: const Text('导入备份（JSON）'),
            subtitle: const Text('从备份文件恢复'),
            onTap: () async {
              try {
                await FilesChannel.instance.startImport();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('选择你的备份文件')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.note_add_outlined, color: colorScheme.tertiary),
            title: const Text('导入笔记（Markdown）'),
            subtitle: const Text('导入 .md 或 .json 文件'),
            onTap: _importNotesFromMarkdown,
          ),

          // Automatic Backup Section
          _buildSectionHeader(context, '自动备份'),
          FutureBuilder<bool>(
            future: AutoBackupService.instance.isAutoBackupScheduled(),
            builder: (context, snapshot) {
              final isScheduled = snapshot.data ?? false;
              final hasPassword =
                  StorageService.getAutoBackupPassword() != null;

              String subtitle;
              if (isScheduled) {
                subtitle = hasPassword
                    ? '已启用（加密）'
                    : '已启用（未加密）';
              } else {
                subtitle = '已禁用 - 点击配置';
              }

              return ListTile(
                leading: Icon(
                  isScheduled ? Icons.backup : Icons.backup_outlined,
                  color: isScheduled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text('配置自动备份'),
                subtitle: Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isScheduled && hasPassword)
                      Icon(Icons.lock, size: 16, color: colorScheme.primary),
                    if (isScheduled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '开',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: _showAutoBackupSetupDialog,
              );
            },
          ),
          FutureBuilder<bool>(
            future: AutoBackupService.instance.isAutoBackupScheduled(),
            builder: (context, snapshot) {
              final isScheduled = snapshot.data ?? false;
              if (!isScheduled) return const SizedBox.shrink();

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('从自动备份恢复'),
                    subtitle: const Text('导入之前的自动备份'),
                    onTap: _showAutoBackupImportDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('查看备份文件'),
                    subtitle: const Text('打开备份文件夹'),
                    onTap: () async {
                      final success = await AutoBackupService.instance
                          .openBackupFolder();
                      if (!context.mounted) return;
                      if (!success) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('备份位置'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('自动备份保存到：'),
                                SpacingGap.gapV8,
                                SelectableText(
                                  'Android/data/com.trudido.app/files/AutoBackups/',
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            actions: [
                              ExpressiveTextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),

          // Help Section
          _buildSectionHeader(context, '关于备份'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: SpacingEdgeInsets.insets16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        SpacingGap.gapH8,
                        Text(
                          '备份选项',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SpacingGap.gapV12,
                    Text(
                      '• JSON 备份包含所有数据并可恢复\n'
                      '• PDF 导出创建可共享的可读文档\n'
                      '• Markdown 文件仅用于笔记\n'
                      '• 自动备份按计划在后台运行',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
