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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permissions_channel.dart';
import '../providers/alarm_settings_providers.dart';
import '../services/system_settings_service.dart';
import '../services/files_channel.dart';

import '../providers/app_providers.dart';
import '../widgets/common/common.dart';

/// Single consolidated settings page using AlarmSettingsWatcher (Riverpod) and unified dialogs.
class UnifiedSettingsPage extends ConsumerStatefulWidget {
  const UnifiedSettingsPage({super.key});
  @override
  ConsumerState<UnifiedSettingsPage> createState() =>
      _UnifiedSettingsPageState();
}

class _UnifiedSettingsPageState extends ConsumerState<UnifiedSettingsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure native files channel is ready
    // ignore: discarded_futures
    FilesChannel.instance.ensureInitialized();

    // Set up import callbacks for refreshing UI
    FilesChannel.instance.setImportCallbacks(
      onComplete: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 2000),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              duration: const Duration(milliseconds: 2500),
            ),
          );
        }
      },
      onRefreshNeeded: () {
        if (mounted) {
          _refreshAllProviders();
        }
      },
    );
  }

  Future<void> _refreshAllProviders() async {
    try {
      // Refresh tasks
      final tasksNotifier = ref.read(tasksProvider.notifier);
      await tasksNotifier.refresh();

      // Refresh preferences state
      ref.invalidate(preferencesStateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '数据已刷新 - 你导入的任务现在应该可见！',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败：$e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_notificationsStatusProvider);
      ref.read(alarmSettingsWatcherProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final watcher = ref.watch(alarmSettingsWatcherProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);
    final perms = PermissionsChannel.instance;
    final notifEnabledAsync = ref.watch(_notificationsStatusProvider);

    final loaded = watcher.loaded;
    return Scaffold(
      appBar: AppBar(title: const Text('提醒可靠性')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger manual refresh
          await watcher.refresh();
          ref.invalidate(_notificationsStatusProvider);
        },
        child: ListView(
          padding: spacing.insets16,
          children: [
            const Text(
              '控制影响提醒时间的权限和系统设置。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: spacing.s16),
            _StatusTile(
              title: '通知',
              status: notifEnabledAsync.maybeWhen(
                orElse: () => true,
                data: (v) => v,
              ),
              description: '需要用于显示提醒和稍后提示。',
              onTap: () async {
                // Always show explicit popup when not granted.
                final enabledNow = await perms.areNotificationsEnabled();
                if (enabledNow) return; // should be disabled tile already
                if (!context.mounted) return;
                final proceed = await _showRationale(
                  context,
                  title: '启用通知',
                  body:
                      '我们使用通知来提醒你即将到来的任务和稍后提醒。'
                      '\n\n在 Android 13+ 上，接下来你将看到系统权限提示。',
                  action: '请求',
                );
                if (!proceed) return;
                if (!context.mounted) return;
                await perms.requestPostNotifications();
                await Future.delayed(const Duration(milliseconds: 300));
                // Double-check and if still disabled offer to open settings
                var stillDisabled = !(await perms.areNotificationsEnabled());
                if (stillDisabled && context.mounted) {
                  final open = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('仍未启用'),
                      content: const Text(
                        '未授予权限。打开系统通知设置？',
                      ),
                      actions: [
                        ExpressiveTextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('打开设置'),
                        ),
                      ],
                    ),
                  );
                  if (open == true) {
                    await perms.openAppNotificationSettings();
                    await Future.delayed(const Duration(milliseconds: 350));
                  }
                }
                ref.invalidate(_notificationsStatusProvider);
              },
            ),
            _StatusTile(
              title: '精确闹钟',
              status: watcher.canExact,
              description: loaded
                  ? '允许在待机/空闲状态下精确定时提醒。'
                  : '检查中…',
              loading: !loaded,
              onTap: () async {
                if (!loaded) {
                  await watcher.refresh();
                  return;
                }
                if (!watcher.canExact) {
                  if (!context.mounted) return;
                  final proceed = await _showRationale(
                    context,
                    title: '启用精确闹钟',
                    body:
                        '精确闹钟让提醒即使在深度休眠或待机时也能准时触发。'
                        '\n\nAndroid 不会显示弹窗。我们将打开系统设置屏幕；在那里切换权限后返回。',
                    action: '打开设置',
                  );
                  if (proceed) {
                    // Directly open settings (single dialog UX)
                    await SystemSettingsService.instance
                        .openExactAlarmSettings();
                  }
                  await Future.delayed(const Duration(milliseconds: 250));
                  await watcher.refresh();
                  if (!watcher.canExact && context.mounted) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('精确闹钟仍未启用。'),
                      ),
                    );
                  }
                }
              },
            ),
            _StatusTile(
              title: '电池优化',
              status: watcher.ignoringBattery,
              description: loaded
                  ? '禁用优化以确保可靠的后台调度。'
                  : '检查中…',
              loading: !loaded,
              onTap: () async {
                if (!loaded) {
                  await watcher.refresh();
                  return;
                }
                if (!watcher.ignoringBattery) {
                  if (!context.mounted) return;
                  final proceed = await _showRationale(
                    context,
                    title: '禁用电池优化',
                    body:
                        '将应用排除在电池优化之外，以免提醒被延迟或取消。'
                        '\n\n我们将打开系统屏幕；确认提示或将应用添加到白名单。',
                    action: '打开设置',
                  );
                  if (proceed) {
                    await SystemSettingsService.instance
                        .requestIgnoreBatteryOptimizations();
                  }
                  await Future.delayed(const Duration(milliseconds: 250));
                  await watcher.refresh();
                  if (!watcher.ignoringBattery && context.mounted) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('电池优化仍处于启用状态。'),
                      ),
                    );
                  }
                }
              },
            ),
            SizedBox(height: spacing.s24),
            const Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.s8),
            const Text(
              '• 精确闹钟不会显示弹窗：你必须在系统设置中手动切换。\n'
              '• 部分 OEM 厂商会添加额外的后台限制；如果持续延迟，请检查自启动/电池菜单。',
            ),
            if (const bool.fromEnvironment('dart.vm.product') == false) ...[
              SizedBox(height: spacing.s32),
              const Text(
                '调试',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing.s8),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await SystemSettingsService.instance
                      .scheduleDebugExactAlarm();
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? '调试精确闹钟已设为约2分钟后'
                            : '安排调试闹钟失败',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.alarm),
                label: const Text('安排调试精确闹钟（2分钟）'),
              ),
              SizedBox(height: spacing.s8),
              const Text(
                '使用此功能强制系统将应用列入"闹钟与提醒"列表。'
                '发布前请移除。',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<bool> _showRationale(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return res == true;
  }
}

// Async notifications status provider (simple FutureProvider wrapper) so UI rebuilds after invalidation.
final _notificationsStatusProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return true;
  return PermissionsChannel.instance.areNotificationsEnabled();
});

class _StatusTile extends StatelessWidget {
  final String title;
  final bool status;
  final String description;
  final VoidCallback onTap;
  final bool loading;
  const _StatusTile({
    required this.title,
    required this.status,
    required this.description,
    required this.onTap,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final color = loading
        ? Theme.of(context).colorScheme.outline
        : status
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    final icon = loading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(status ? Icons.check_circle : Icons.info_outline, color: color);
    return Card(
      child: ListTile(
        leading: icon,
        title: Text(title),
        subtitle: Text(
          '$description\n状态：${loading
              ? '…'
              : status
              ? '已启用'
              : '已禁用'}',
        ),
        isThreeLine: true,
        trailing: (status || loading) ? null : const Icon(Icons.arrow_forward),
        onTap: (status || loading) ? null : onTap,
      ),
    );
  }
}
