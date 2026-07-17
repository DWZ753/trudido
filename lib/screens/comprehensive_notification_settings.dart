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
import '../providers/app_providers.dart';
import '../services/notification_service.dart';

class ComprehensiveNotificationSettings extends ConsumerStatefulWidget {
  const ComprehensiveNotificationSettings({super.key});

  @override
  ConsumerState<ComprehensiveNotificationSettings> createState() =>
      _ComprehensiveNotificationSettingsState();
}

class _ComprehensiveNotificationSettingsState
    extends ConsumerState<ComprehensiveNotificationSettings>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmSettingsWatcherProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExactAlarms = ref.watch(canExactAlarmsProvider);
    final ignoringBattery = ref.watch(ignoringBatteryOptimizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          // Permissions Section
          _buildSectionHeader(context, '权限'),

          FutureBuilder<bool>(
            future: PermissionsChannel.instance.areNotificationsEnabled(),
            builder: (context, snapshot) {
              final isGranted = snapshot.data ?? false;
              return _buildPermissionTile(
                context: context,
                icon: Icons.notifications,
                title: '通知权限',
                subtitle: '允许应用显示通知',
                isGranted: isGranted,
                onTap: () =>
                    PermissionsChannel.instance.openAppNotificationSettings(),
              );
            },
          ),

          _buildPermissionTile(
            context: context,
            icon: Icons.alarm,
            title: '精确闹钟',
            subtitle: '提醒的精确定时',
            isGranted: canExactAlarms,
            onTap: () => PermissionsChannel.instance.openExactAlarmSettings(),
          ),

          _buildPermissionTile(
            context: context,
            icon: Icons.battery_full,
            title: '电池优化',
            subtitle: '禁用以确保通知正常工作',
            isGranted: ignoringBattery,
            onTap: () =>
                PermissionsChannel.instance.openBatteryOptimizationSettings(),
          ),

          // Behavior Section
          _buildSectionHeader(context, '行为'),

          SwitchListTile(
            secondary: const Icon(Icons.push_pin_outlined),
            title: const Text('持久通知'),
            subtitle: const Text(
              '通知被关闭后会立即重新出现。'
              '只有"完成"和"稍后提醒"按钮可以移除它们。',
            ),
            value: ref.watch(preferencesStateProvider).persistentNotifications,
            onChanged: (value) async {
              final svc = ref.read(preferencesServiceProvider);
              final updated = await svc.update(persistentNotifications: value);
              ref.read(preferencesStateProvider.notifier).update(updated);
              // Sync to native SharedPreferences so receivers can read it
              await NotificationBridge.instance.setPersistentNotifications(
                value,
              );
            },
          ),

          // System Settings Section
          _buildSectionHeader(context, '系统设置'),

          ListTile(
            leading: Icon(Icons.settings),
            title: const Text('应用通知设置'),
            subtitle: const Text('打开此应用的系统设置'),
            trailing: Icon(Icons.open_in_new),
            onTap: () =>
                PermissionsChannel.instance.openAppNotificationSettings(),
          ),

          if (Platform.isAndroid) ...[
            ListTile(
              leading: Icon(Icons.battery_full),
              title: const Text('电池设置'),
              subtitle: const Text('打开电池优化设置'),
              trailing: Icon(Icons.open_in_new),
              onTap: () =>
                  PermissionsChannel.instance.openBatteryOptimizationSettings(),
            ),
            ListTile(
              leading: Icon(Icons.alarm),
              title: const Text('闹钟与提醒'),
              subtitle: const Text('打开系统闹钟设置'),
              trailing: Icon(Icons.open_in_new),
              onTap: () => PermissionsChannel.instance.openExactAlarmSettings(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final statusColor = isGranted ? Colors.green : Colors.orange;
    final statusText = isGranted ? '已授予' : '需要';

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withAlpha(77)),
        ),
        child: Text(
          statusText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: isGranted ? null : onTap,
    );
  }
}
