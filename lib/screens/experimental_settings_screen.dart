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
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../utils/responsive_size.dart';
import 'template_management_screen.dart';

class ExperimentalSettingsScreen extends ConsumerWidget {
  const ExperimentalSettingsScreen({super.key});

  Future<void> _handleQuickInputBarToggle(
    BuildContext context,
    WidgetRef ref,
    bool nextValue,
  ) async {
    final preferences = ref.read(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);

    if (nextValue == preferences.useQuickInputBar) {
      return;
    }

    // Only guard the enable path when floating nav bar is active.
    if (nextValue && preferences.floatingNavBar) {
      final disableFloatingBar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('关闭浮动导航栏？'),
          content: const Text(
            '快速输入栏与浮动导航栏不兼容。要使用快速输入栏，请关闭浮动导航栏。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('关闭浮动栏'),
            ),
          ],
        ),
      );

      if (disableFloatingBar != true) {
        return;
      }

      await controller.toggleFloatingNavBar();
      if (context.mounted) {
        await controller.toggleQuickInputBar();
      }
      return;
    }

    await controller.toggleQuickInputBar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('实验性'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '这些功能正在开发中，可能包含错误。风险自负。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: ScaledIcon(Icons.widgets_outlined),
            title: const Text('文件夹模板'),
            subtitle: const Text('管理智能文件夹创建模板'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementScreen(),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.edit_note_outlined),
                title: const Text('快速输入栏'),
                subtitle: const Text(
                  '用底部输入栏替代浮动操作按钮，快速创建任务/笔记',
                ),
                value: preferences.useQuickInputBar,
                onChanged: (v) => _handleQuickInputBarToggle(context, ref, v),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('笔记历史'),
                subtitle: const Text(
                  '启用带有撤销/重做和版本浏览的笔记历史',
                ),
                value: preferences.enableNoteHistory,
                onChanged: (v) => controller.toggleNoteHistory(),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.space_dashboard_outlined),
                title: const Text('空间画布'),
                subtitle: const Text(
                  '启用带有平移和缩放控制的空间画布笔记视图',
                ),
                value: preferences.enableSpatialCanvas,
                onChanged: (v) => controller.toggleSpatialCanvas(),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.event_available_outlined),
                title: const Text('自动完成事件'),
                subtitle: const Text(
                  '在事件结束时间过后自动标记为完成',
                ),
                value: preferences.autoCompleteEvents,
                onChanged: (v) => controller.toggleAutoCompleteEvents(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
