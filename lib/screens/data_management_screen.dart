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
import '../controllers/task_controller.dart';
import '../utils/responsive_size.dart';
import 'calendar_sync_settings_screen.dart';
import 'holiday_calendar_settings_screen.dart';
import 'backup_settings_page.dart';
import 'bin_settings_screen.dart';
import '../widgets/common/common.dart';
import '../providers/filter_providers.dart';
import '../providers/app_providers.dart';
import '../services/ics_export_service.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final taskStats = ref.watch(taskStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: ScaledIcon(Icons.calendar_month_outlined),
            title: const Text('日历同步'),
            subtitle: const Text('与 Android/DAVx5 日历同步任务'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              ref.read(recentSettingsProvider.notifier).record('calendar_sync');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CalendarSyncSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.event),
            title: const Text('导入日历'),
            subtitle: const Text('从 .ics 文件导入日程'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              ref
                  .read(recentSettingsProvider.notifier)
                  .record('holiday_calendar');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HolidayCalendarSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.ios_share_outlined),
            title: const Text('导出日历'),
            subtitle: const Text('将日程导出为 .ics 文件'),
            onTap: () async {
              final events = ref.read(eventsProvider);
              if (events.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('没有可导出的日程')),
                );
                return;
              }
              await IcsExportService.exportAndShareEvents(
                events,
                filename: 'trudido_events.ics',
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.save_alt),
            title: const Text('备份与数据'),
            subtitle: const Text('导出、导入和自动备份'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              ref.read(recentSettingsProvider.notifier).record('backup');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.delete_outline),
            title: const Text('回收站设置'),
            subtitle: const Text('启用或禁用回收站，设置自动删除'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              ref.read(recentSettingsProvider.notifier).record('bin');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BinSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(
              Icons.warning_amber_outlined,
              color: colorScheme.error,
            ),
            title: Text(
              '危险区域',
              style: TextStyle(color: colorScheme.error),
            ),
            subtitle: const Text('清除任务和重置数据'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () => _showDangerZoneSheet(context, ref, taskStats),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDangerZoneSheet(BuildContext context, WidgetRef ref, statistics) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _DangerZoneSheet(statistics: statistics),
    );
  }
}

class _DangerZoneSheet extends ConsumerWidget {
  final dynamic statistics;
  const _DangerZoneSheet({required this.statistics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '危险区域',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '这些操作无法撤消。请谨慎操作。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: ScaledIcon(Icons.delete_outline, color: cs.error),
            title: Text(
              '清除已完成的任务',
              style: TextStyle(color: cs.error),
            ),
            subtitle: Text(
              '删除所有已完成的任务（共 ${statistics.completed} 项）',
            ),
            onTap: () {
              Navigator.of(context).pop();
              _showClearCompletedDialog(context, ref);
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.warning_amber_outlined, color: cs.error),
            title: Text('清除所有数据', style: TextStyle(color: cs.error)),
            subtitle: const Text('删除所有任务和分类'),
            onTap: () {
              Navigator.of(context).pop();
              _showClearAllDataDialog(context, ref);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showClearCompletedDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已完成的任务'),
        content: const Text(
          '确定要删除所有已完成的任务吗？此操作无法撤消。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在清除已完成的任务...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await ref.read(taskControllerProvider.notifier).clearCompleted();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已完成的任务已清除')),
                );
              }
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text(
          '确定要删除所有任务和分类吗？这将永久删除所有数据且无法撤消。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在清除所有数据...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await ref.read(taskControllerProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有数据已清除')),
                );
              }
            },
            child: const Text('清除全部'),
          ),
        ],
      ),
    );
  }
}
