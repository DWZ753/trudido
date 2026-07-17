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
import 'package:intl/intl.dart';
import '../services/calendar_sync_service.dart';
import '../providers/app_providers.dart';
import '../providers/holiday_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/event_controller.dart';
import '../utils/responsive_size.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Provider for calendar sync service
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService();
});

/// Provider for calendar sync status
final calendarSyncStatusProvider = FutureProvider<CalendarSyncStatus>((
  ref,
) async {
  final service = ref.watch(calendarSyncServiceProvider);
  await service.ensureInitialized();
  return service.getSyncStatus();
});

/// Settings screen for calendar sync configuration
class CalendarSyncSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSyncSettingsScreen> createState() =>
      _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState
    extends ConsumerState<CalendarSyncSettingsScreen> {
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(calendarSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('日历同步')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, error.toString()),
        data: (status) => _buildContent(context, status),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: SpacingEdgeInsets.insets24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            SpacingGap.gapV16,
            Text(
              '加载日历设置时出错',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SpacingGap.gapV8,
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SpacingGap.gapV24,
            FilledButton.icon(
              onPressed: () => ref.invalidate(calendarSyncStatusProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CalendarSyncStatus status) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final service = ref.read(calendarSyncServiceProvider);

    return ListView(
      children: [
        // Info card about DAVx5
        _buildInfoCard(context),

        // Enable/Disable sync
        SwitchListTile(
          secondary: ScaledIcon(Icons.sync, color: cs.primary),
          title: const Text('启用日历同步'),
          subtitle: const Text('与设备日历同步任务'),
          value: status.isEnabled,
          onChanged: _isLoading
              ? null
              : (value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  if (value && !status.hasPermissions) {
                    final granted = await service.requestPermissions();
                    if (!granted) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('需要日历权限'),
                          ),
                        );
                      }
                      setState(() => _isLoading = false);
                      return;
                    }
                  }
                  await service.setEnabled(value);
                  ref.invalidate(calendarSyncStatusProvider);
                  setState(() => _isLoading = false);
                },
        ),

        if (status.isEnabled) ...[
          const Divider(),

          // Permission status
          if (!status.hasPermissions)
            ListTile(
              leading: ScaledIcon(Icons.warning_amber, color: cs.error),
              title: const Text('需要日历权限'),
              subtitle: const Text('点击授予权限'),
              trailing: FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final granted = await service.requestPermissions();
                  ref.invalidate(calendarSyncStatusProvider);
                  if (!granted && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          '请在设置中启用日历权限',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('授予'),
              ),
            ),

          // Calendar selection
          if (status.hasPermissions) ...[
            _buildSectionHeader(context, '日历'),
            ListTile(
              leading: ScaledIcon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('添加日历'),
              subtitle: Text(
                status.selectedCalendars.isEmpty
                    ? '未选择日历'
                    : '已配置 ${status.selectedCalendars.length} 个日历',
              ),
              trailing: const ScaledIcon(Icons.arrow_forward_ios),
              onTap: () => _showAddCalendarPicker(context, status),
            ),

            // List of selected calendars
            if (status.selectedCalendars.isNotEmpty) ...[
              ...status.selectedCalendars.map(
                (cal) => _buildSelectedCalendarTile(
                  context,
                  cal,
                  status.primaryExportCalendarId == cal.id,
                ),
              ),
            ],

            if (status.availableCalendars.isEmpty)
              Padding(
                padding: SpacingEdgeInsets.insets16,
                child: Card(
                  color: cs.tertiaryContainer,
                  child: Padding(
                    padding: SpacingEdgeInsets.insets16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ScaledIcon(
                              Icons.info_outline,
                              color: cs.onTertiaryContainer,
                            ),
                            SpacingGap.gapH16,
                            Expanded(
                              child: Text(
                                '未找到可写入的日历',
                                style: TextStyle(
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SpacingGap.gapV8,
                        if (status.allCalendars.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Text(
                              '找到 ${status.allCalendars.length} 个日历，但均为只读：',
                              style: TextStyle(
                                color: cs.onTertiaryContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...status.allCalendars.map(
                            (cal) => Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Text(
                                '• ${cal.name.isNotEmpty ? cal.name : "Unknown"} (${cal.accountName ?? ""})',
                                style: TextStyle(
                                  color: cs.onTertiaryContainer,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SpacingGap.gapV8,
                        ],
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            '提示：\n'
                            '• 如果使用 DAVx5，请打开 DAVx5 并同步你的日历\n'
                            '• 确保日历账户设置为"同步"\n'
                            '• 检查日历在 DAVx5 中是否有写入权限\n'
                            '• 同步后尝试刷新此页面',
                            style: TextStyle(
                              color: cs.onTertiaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SpacingGap.gapV12,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExpressiveOutlinedButton.icon(
                              onPressed: () {
                                ref.invalidate(calendarSyncStatusProvider);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('刷新'),
                            ),
                            SpacingGap.gapH8,
                            ExpressiveOutlinedButton.icon(
                              onPressed: () => _showDiagnostics(context),
                              icon: const Icon(Icons.bug_report),
                              label: const Text('诊断'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Sync options
            _buildSectionHeader(context, '同步选项'),
            SwitchListTile(
              secondary: ScaledIcon(Icons.play_circle_outline),
              title: const Text('启动时自动同步'),
              subtitle: const Text('应用打开时同步日历'),
              value: status.autoSyncOnStartup,
              onChanged: (value) async {
                await service.setAutoSyncOnStartup(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),
            SwitchListTile(
              secondary: ScaledIcon(Icons.check_circle_outline),
              title: const Text('同步已完成的任务'),
              subtitle: const Text('在日历中包含已完成的任务'),
              value: status.syncCompletedTasks,
              onChanged: (value) async {
                await service.setSyncCompletedTasks(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),
            SwitchListTile(
              secondary: ScaledIcon(Icons.swap_vert),
              title: const Text('双向同步'),
              subtitle: const Text('将日历事件导入为事件'),
              value: status.twoWaySyncEnabled,
              onChanged: (value) async {
                await service.setTwoWaySyncEnabled(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),

            // Manual sync button
            if (status.isConfigured) ...[
              _buildSectionHeader(context, '操作'),
              ListTile(
                leading: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ScaledIcon(Icons.upload, color: cs.primary),
                title: const Text('导出任务到日历'),
                subtitle: const Text('将所有任务推送到主日历'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _syncAllTasks(context),
              ),
              ListTile(
                leading: _isImporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ScaledIcon(Icons.download, color: cs.primary),
                title: const Text('从日历导入事件'),
                subtitle: const Text('从所有导入日历拉取事件'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showImportDialog(context, status),
              ),
              if (status.twoWaySyncEnabled)
                ListTile(
                  leading: (_isSyncing || _isImporting)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ScaledIcon(Icons.sync, color: cs.tertiary),
                  title: const Text('完整双向同步'),
                  subtitle: const Text('导出任务并导入事件'),
                  enabled: !_isSyncing && !_isImporting,
                  onTap: () => _performTwoWaySync(context),
                ),

              _buildSectionHeader(context, '维护'),
              ListTile(
                leading: ScaledIcon(
                  Icons.cleaning_services,
                  color: cs.secondary,
                ),
                title: const Text('移除重复事件'),
                subtitle: const Text('清理重复的 Trudido 事件'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showCleanupDuplicatesDialog(context, status),
              ),
              ListTile(
                leading: ScaledIcon(Icons.delete_forever, color: cs.error),
                title: Text(
                  '删除所有 Trudido 事件',
                  style: TextStyle(color: cs.error),
                ),
                subtitle: const Text(
                  '从日历中移除所有导出的事件',
                ),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showDeleteAllEventsDialog(context, status),
              ),

              if (status.lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '上次同步：${_formatDateTime(status.lastSyncTime!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: ScaledIcon(Icons.delete_sweep, color: cs.error),
                title: Text(
                  '移除所有日历',
                  style: TextStyle(color: cs.error),
                ),
                subtitle: const Text('断开所有日历'),
                onTap: () => _showDisconnectAllDialog(context),
              ),
            ],
          ],
        ],

        // Always show diagnostics option for troubleshooting
        if (status.isEnabled) ...[
          const Divider(),
          ListTile(
            leading: ScaledIcon(Icons.bug_report, color: cs.outline),
            title: const Text('日历诊断'),
            subtitle: const Text('查看技术详情以进行故障排除'),
            onTap: () => _showDiagnostics(context),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showDiagnostics(BuildContext context) async {
    final service = ref.read(calendarSyncServiceProvider);
    final diagnostics = await service.getDiagnosticInfo();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('日历诊断'),
        content: SingleChildScrollView(
          child: SelectableText(
            diagnostics,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: SpacingEdgeInsets.insets16,
      child: Card(
        color: cs.primaryContainer,
        child: Padding(
          padding: SpacingEdgeInsets.insets16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScaledIcon(
                    Icons.calendar_today,
                    color: cs.onPrimaryContainer,
                  ),
                  SpacingGap.gapH12,
                  Text(
                    'DAVx5 集成',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SpacingGap.gapV12,
              Text(
                '对于 CalDAV 同步（Nextcloud 等）：\n'
                '1. 从 F-Droid 或 Play Store 安装 DAVx5\n'
                '2. 在 DAVx5 中添加你的 CalDAV 账户\n'
                '3. 在 DAVx5 中同步你的日历\n'
                '4. 在下方选择已同步的日历\n\n'
                '你的任务将同步到 Android 日历，DAVx5 负责处理 CalDAV 同步。',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelectedCalendarTile(
    BuildContext context,
    SelectedCalendar cal,
    bool isPrimary,
  ) {
    final cs = Theme.of(context).colorScheme;
    final service = ref.read(calendarSyncServiceProvider);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(cal.color),
        radius: 16,
        child: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
      ),
      title: Row(
        children: [
          Expanded(child: Text(cal.name)),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '主要',
                style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          if (cal.isForExport)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(label: const Text('导出')),
            ),
          if (cal.isForImport) Chip(label: const Text('导入')),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'primary':
              await service.setPrimaryExportCalendar(cal.id);
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'toggle_export':
              await service.updateSelectedCalendar(
                cal.copyWith(isForExport: !cal.isForExport),
              );
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'toggle_import':
              await service.updateSelectedCalendar(
                cal.copyWith(isForImport: !cal.isForImport),
              );
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'remove':
              await service.removeSelectedCalendar(cal.id);
              ref.invalidate(calendarSyncStatusProvider);
              break;
          }
        },
        itemBuilder: (context) => [
          if (!isPrimary && cal.isForExport)
            const PopupMenuItem(
              value: 'primary',
              child: ListTile(
                leading: Icon(Icons.star),
                title: Text('设为主要'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'toggle_export',
            child: ListTile(
              leading: Icon(
                cal.isForExport ? Icons.cloud_off : Icons.cloud_upload,
              ),
              title: Text(cal.isForExport ? '禁用导出' : '启用导出'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'toggle_import',
            child: ListTile(
              leading: Icon(
                cal.isForImport ? Icons.cloud_off : Icons.cloud_download,
              ),
              title: Text(cal.isForImport ? '禁用导入' : '启用导入'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: Text('移除', style: TextStyle(color: cs.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCalendarPicker(BuildContext context, CalendarSyncStatus status) {
    // Filter out already selected calendars
    final availableCalendars = status.availableCalendars
        .where((c) => !status.selectedCalendars.any((s) => s.id == c.id))
        .toList();

    if (availableCalendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.availableCalendars.isEmpty
                ? '没有可用的可写入日历'
                : '所有可用日历已添加',
          ),
        ),
      );
      return;
    }

    final service = ref.read(calendarSyncServiceProvider);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '添加日历',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '选择要同步的日历。你可以添加工作、个人、共享日历等。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SpacingGap.gapV8,
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: availableCalendars.length,
                  itemBuilder: (context, index) {
                    final calendar = availableCalendars[index];
                    final name = calendar.name;
                    final accountName = calendar.accountName;
                    final displayName = name.isNotEmpty
                        ? name
                        : (accountName?.isNotEmpty ?? false)
                        ? accountName!
                        : 'Calendar ${calendar.id}';
                    final subtitle =
                        (accountName?.isNotEmpty ?? false) && name.isNotEmpty
                        ? accountName!
                        : '';
                    final calendarColor = CalendarSyncService.parseColorHex(
                      calendar.colorHex,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(calendarColor),
                        radius: 16,
                        child: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: Text(subtitle),
                      onTap: () async {
                        await service.addSelectedCalendar(
                          SelectedCalendar(
                            id: calendar.id,
                            name: displayName,
                            color: calendarColor,
                            isForExport: true,
                            isForImport: true,
                          ),
                        );
                        ref.invalidate(calendarSyncStatusProvider);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              SpacingGap.gapV16,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncAllTasks(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final tasks = ref.read(tasksProvider);

      // Perform full two-way sync
      final now = DateTime.now();
      final result = await service.performTwoWaySync(
        existingTasks: tasks,
        syncStartDate: now.subtract(const Duration(days: 30)),
        syncEndDate: now.add(const Duration(days: 90)),
      );

      if (result.imported.isNotEmpty) {
        final eventController = ref.read(eventControllerProvider.notifier);
        for (final event in result.imported) {
          await eventController.add(event);
        }
      }

      ref.invalidate(calendarSyncStatusProvider);

      if (mounted) {
        String message = '已同步 ${result.exported} 个任务到日历';
        if (result.imported.isNotEmpty) {
          message += '，已导入 ${result.imported.length} 个事件';
        }
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showDisconnectAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除所有日历'),
        content: const Text(
          '这将停止与所有日历的任务同步。'
          '现有的日历事件不会被删除。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final service = ref.read(calendarSyncServiceProvider);
              await service.clearSelectedCalendars();
              await service.setEnabled(false);
              ref.invalidate(calendarSyncStatusProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('全部移除'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    } else {
      return DateFormat('MMM d, yyyy HH:mm').format(dt);
    }
  }

  void _showImportDialog(BuildContext context, CalendarSyncStatus status) {
    bool importEverything = true;
    bool skipAlreadyImported = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入日历事件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '从你选择的日历中导入事件。'
                'Trudido 导出的事件将被跳过。',
              ),
              SpacingGap.gapV16,
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('导入所有事件'),
                subtitle: const Text('过去一年和未来两年'),
                value: importEverything,
                onChanged: (value) {
                  setDialogState(() => importEverything = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('跳过已导入的'),
                subtitle: const Text('取消勾选以重新导入所有事件'),
                value: skipAlreadyImported,
                onChanged: (value) {
                  setDialogState(() => skipAlreadyImported = value ?? true);
                },
              ),
            ],
          ),
          actions: [
            ExpressiveTextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final startDate = importEverything
                    ? now.subtract(const Duration(days: 365))
                    : now.subtract(const Duration(days: 30));
                final endDate = importEverything
                    ? now.add(const Duration(days: 730))
                    : now.add(const Duration(days: 90));
                _importEvents(startDate, endDate, skipAlreadyImported);
              },
              child: const Text('导入'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importEvents(
    DateTime startDate,
    DateTime endDate, [
    bool skipAlreadyImported = true,
  ]) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isImporting = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final calendarsToImport = service.selectedCalendars
          .where((c) => c.isForImport)
          .toList();

      if (calendarsToImport.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('未选择用于导入的日历')),
          );
        }
        return;
      }

      int totalAdded = 0;
      final eventController = ref.read(eventControllerProvider.notifier);

      for (final calendar in calendarsToImport) {
        final importedEvents = await service.importEventsFromCalendarAsEvents(
          calendarId: calendar.id,
          startDate: startDate,
          endDate: endDate,
          skipAlreadyImported: skipAlreadyImported,
        );

        for (final event in importedEvents) {
          await eventController.add(event);
          totalAdded++;
        }
      }

      if (totalAdded == 0) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('没有新事件可导入')),
          );
        }
        return;
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('已导入 $totalAdded 个事件')),
        );
      }

      ref.invalidate(calendarSyncStatusProvider);

      // Check for past imported tasks and offer to mark them complete
      if (mounted) {
        await _checkAndOfferMarkPastComplete(context);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _performTwoWaySync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSyncing = true;
      _isImporting = true;
    });

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final tasks = ref.read(tasksProvider);
      final now = DateTime.now();

      final result = await service.performTwoWaySync(
        existingTasks: tasks,
        syncStartDate: now.subtract(const Duration(days: 30)),
        syncEndDate: now.add(const Duration(days: 90)),
      );

      if (result.imported.isNotEmpty) {
        final eventController = ref.read(eventControllerProvider.notifier);
        for (final event in result.imported) {
          await eventController.add(event);
        }
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '已导出 ${result.exported} 个任务，已导入 ${result.imported.length} 个事件',
            ),
          ),
        );
      }

      ref.invalidate(calendarSyncStatusProvider);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
      }
    } finally {
      setState(() {
        _isSyncing = false;
        _isImporting = false;
      });
    }
  }

  void _showCleanupDuplicatesDialog(
    BuildContext context,
    CalendarSyncStatus status,
  ) {
    final primaryCal = status.primaryExportCalendar;
    if (primaryCal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未设置主导出日历')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除重复事件'),
        content: Text(
          '这将搜索由 Trudido 在"${primaryCal.name}"中创建的重复事件并移除它们，'
          '每个任务只保留一个事件。\n\n'
          '如果你不小心多次同步了相同的任务，这会很有用。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cleanupDuplicates(primaryCal.id);
            },
            child: const Text('清理'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupDuplicates(String calendarId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final now = DateTime.now();

      final deleted = await service.deleteDuplicateTrudidoEvents(
        calendarId: calendarId,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now.add(const Duration(days: 730)),
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              deleted > 0
                  ? '已移除 $deleted 个重复事件'
                  : '未找到重复项',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('清理失败：$e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showDeleteAllEventsDialog(
    BuildContext context,
    CalendarSyncStatus status,
  ) {
    final primaryCal = status.primaryExportCalendar;
    if (primaryCal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未设置主导出日历')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所有 Trudido 事件'),
        icon: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
        content: Text(
          '这将永久删除 Trudido 在"${primaryCal.name}"中创建的所有事件。\n\n'
          '此操作无法撤销。你在 Trudido 中的任务不会受到影响。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllTrudidoEvents(primaryCal.id);
            },
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllTrudidoEvents(String calendarId) async {
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final now = DateTime.now();

      final deleted = await service.deleteAllTrudidoEvents(
        calendarId: calendarId,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now.add(const Duration(days: 730)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已从日历删除 $deleted 个事件')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _checkAndOfferMarkPastComplete(BuildContext context) async {
    // Wait a moment for providers to refresh
    await Future.delayed(const Duration(milliseconds: 300));

    final pastTasks = ref.read(pastImportedUncompletedTasksProvider);
    if (pastTasks.isEmpty) return;

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('标记过去任务为已完成？'),
        content: Text(
          '你导入了 ${pastTasks.length} 个截止日期在过去的任务。\n\n'
          '是否要将它们标记为已完成？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('否'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('标记完成'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final taskController = ref.read(taskControllerProvider.notifier);
      final ids = pastTasks.map((t) => t.id);
      await taskController.bulkComplete(ids);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '已将 ${pastTasks.length} 个过去任务标记为完成',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
