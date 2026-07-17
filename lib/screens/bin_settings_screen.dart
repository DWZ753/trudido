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

class BinSettingsScreen extends ConsumerWidget {
  const BinSettingsScreen({super.key});

  static const List<_AutoDeleteOption> _autoDeleteOptions = [
    _AutoDeleteOption(days: 0, label: '从不'),
    _AutoDeleteOption(days: 1, label: '1天'),
    _AutoDeleteOption(days: 7, label: '7天'),
    _AutoDeleteOption(days: 14, label: '14天'),
    _AutoDeleteOption(days: 30, label: '30天'),
    _AutoDeleteOption(days: 60, label: '60天'),
    _AutoDeleteOption(days: 90, label: '90天'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);

    final enableBin = preferences.enableBin;
    final autoDeleteDays = preferences.autoDeleteDaysInBin;

    String autoDeleteLabel;
    if (autoDeleteDays <= 0) {
      autoDeleteLabel = '从不';
    } else {
      autoDeleteLabel = autoDeleteDays == 1 ? '1天' : '$autoDeleteDays天';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站设置'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Enable / disable the bin
          SwitchListTile(
            secondary: ScaledIcon(Icons.delete_outline),
            title: const Text('启用回收站'),
            subtitle: const Text(
              '关闭后，删除项目将永久移除，不会进入回收站',
            ),
            value: enableBin,
            onChanged: (value) => controller.setEnableBin(value),
          ),

          const Divider(height: 1),

          // Auto-delete after N days
          ListTile(
            enabled: enableBin,
            leading: ScaledIcon(Icons.schedule),
            title: const Text('自动删除期限'),
            subtitle: Text(
              autoDeleteDays > 0
                  ? '回收站中的项目将在${autoDeleteDays == 1 ? '1天' : '$autoDeleteDays天'}后永久删除'
                  : '回收站中的项目不会自动删除',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  autoDeleteLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: enableBin
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                ScaledIcon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: enableBin
                ? () => _showAutoDeletePicker(
                    context,
                    ref,
                    controller,
                    autoDeleteDays,
                  )
                : null,
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '注意：启用自动删除后，每次应用启动时会检查过期项目。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAutoDeletePicker(
    BuildContext context,
    WidgetRef ref,
    PreferencesController controller,
    int currentDays,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '自动删除回收站中的项目期限',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              RadioGroup<int>(
                groupValue: currentDays,
                onChanged: (value) async {
                  if (value != null) {
                    await controller.setAutoDeleteDaysInBin(value);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _autoDeleteOptions
                      .map(
                        (option) => RadioListTile<int>(
                          title: Text(option.label),
                          value: option.days,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoDeleteOption {
  final int days;
  final String label;
  const _AutoDeleteOption({required this.days, required this.label});
}
