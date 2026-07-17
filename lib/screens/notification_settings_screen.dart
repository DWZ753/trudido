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
import '../services/notification_service.dart';
import '../widgets/common/common.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = NotificationBridge.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知测试'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '测试与管理通知',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.science),
                  title: const Text('测试计划（10秒）'),
                  subtitle: const Text(
                    '从现在起10秒后发送通知。',
                  ),
                  trailing: ExpressiveElevatedButton(
                    onPressed: () async {
                      final dt = DateTime.now().add(
                        const Duration(seconds: 10),
                      );
                      await bridge.scheduleTaskNotification(
                        taskId: 'test-10s',
                        title: '测试通知',
                        body: '10秒后触发',
                        scheduledTime: dt,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已安排10秒后的测试通知'),
                        ),
                      );
                    },
                    child: const Text('安排'),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: const Text('取消测试通知'),
                  subtitle: const Text(
                    '取消待处理的测试通知。',
                  ),
                  trailing: ExpressiveElevatedButton(
                    style: ExpressiveElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[800],
                    ),
                    onPressed: () async {
                      await bridge.cancelTaskNotification('test-10s');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已取消测试通知'),
                        ),
                      );
                    },
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '通知工作原理',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 当你为任务设置截止日期时，通知会自动安排。\n'
                    '• 通知会在你指定的确切时间发送。\n'
                    '• 当你完成或删除任务时，通知会自动取消。',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // legacy test helpers removed with new native system
}
