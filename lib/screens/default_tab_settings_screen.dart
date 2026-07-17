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
import '../services/default_tab_service.dart';
import '../providers/app_providers.dart';
import '../services/preferences_service.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Provider for the current default tab setting
final defaultTabProvider = FutureProvider<String>((ref) async {
  return await DefaultTabService.getDefaultTab();
});

/// Provider for saving default tab changes
final defaultTabNotifierProvider =
    NotifierProvider<DefaultTabNotifier, AsyncValue<String>>(
      DefaultTabNotifier.new,
    );

/// State notifier for managing default tab changes
class DefaultTabNotifier extends Notifier<AsyncValue<String>> {
  @override
  AsyncValue<String> build() {
    _loadCurrentTab();
    return const AsyncValue.loading();
  }

  Future<void> _loadCurrentTab() async {
    try {
      final tab = await DefaultTabService.getDefaultTab();
      state = AsyncValue.data(tab);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setDefaultTab(String tabId) async {
    state = const AsyncValue.loading();
    try {
      final success = await DefaultTabService.setDefaultTab(tabId);
      if (success) {
        state = AsyncValue.data(tabId);
      } else {
        throw Exception('Failed to save default tab setting');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> resetToDefault() async {
    state = const AsyncValue.loading();
    try {
      await DefaultTabService.resetToDefault();
      final tab = await DefaultTabService.getDefaultTab();
      state = AsyncValue.data(tab);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Default Tab Settings Screen
///
/// This screen allows users to choose their preferred starting tab.
/// It integrates with your app's Material Design 3 theme
/// and follows Android best practices for settings UI.
class DefaultTabSettingsScreen extends ConsumerWidget {
  const DefaultTabSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTabAsync = ref.watch(defaultTabNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('默认起始标签'),
        centerTitle: false,
      ),
      body: defaultTabAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              SpacingGap.gapV16,
              Text(
                '加载设置失败',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SpacingGap.gapV8,
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              SpacingGap.gapV16,
              ExpressiveElevatedButton.icon(
                onPressed: () => ref.refresh(defaultTabNotifierProvider),
                icon: Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (currentTab) => _buildSettingsBody(context, ref, currentTab),
      ),
    );
  }

  Widget _buildSettingsBody(
    BuildContext context,
    WidgetRef ref,
    String currentTab,
  ) {
    final tabs = DefaultTabService.getAllTabs();
    final hideBottomNav = ref
        .watch(preferencesStateProvider)
        .hideBottomNavigation;

    return ListView(
      padding: SpacingEdgeInsets.insets16,
      children: [
        // Main settings card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: SpacingEdgeInsets.insets8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: SpacingBorderRadius.sm,
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    SpacingGap.gapH16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '默认起始标签',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '选择启动应用时打开的标签',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SpacingGap.gapV24,

                // Tab selection options
                ...tabs.entries.map(
                  (entry) => _buildTabOption(
                    context,
                    ref,
                    entry.key,
                    entry.value,
                    currentTab,
                  ),
                ),
              ],
            ),
          ),
        ),

        SpacingGap.gapV16,

        // Bottom navigation visibility toggle
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            title: const Text('显示底部导航'),
            subtitle: const Text('隐藏底部标签栏和导航栏'),
            value: !hideBottomNav,
            onChanged: (value) async {
              final prefsService = PreferencesService();
              final updated = await prefsService.update(
                hideBottomNavigation: !value,
              );
              ref.read(preferencesStateProvider.notifier).update(updated);
            },
          ),
        ),

        SpacingGap.gapV16,

        // Information card
        Card(
          child: Padding(
            padding: SpacingEdgeInsets.insets16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SpacingGap.gapH12,
                    Text(
                      '关于此设置',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SpacingGap.gapV12,
                Text(
                  '选择的标签将在每次打开应用时显示。'
                  '此设置保存在你的设备本地，可随时更改。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        SpacingGap.gapV16,

        // Reset button
        SizedBox(
          width: double.infinity,
          child: ExpressiveOutlinedButton.icon(
            onPressed: () => _showResetDialog(context, ref),
            icon: Icon(Icons.undo),
            label: const Text('重置为默认（任务）'),
          ),
        ),
      ],
    );
  }

  Widget _buildTabOption(
    BuildContext context,
    WidgetRef ref,
    String tabId,
    String tabName,
    String currentTab,
  ) {
    final isSelected = currentTab == tabId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpressiveInkWell(
        onTap: () => _selectTab(context, ref, tabId, tabName),
        borderRadius: SpacingBorderRadius.sm,
        child: Container(
          padding: SpacingEdgeInsets.insets12,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: SpacingBorderRadius.sm,
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withAlpha((255 * 0.3).round())
                : null,
          ),
          child: Row(
            children: [
              Icon(
                _getTabIcon(tabId),
                size: 24,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SpacingGap.gapH16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tabName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    Text(
                      _getTabDescription(tabId),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTabIcon(String tabId) {
    switch (tabId) {
      case 'overview':
        return Icons.dashboard;
      case 'tasks':
        return Icons.checklist;
      case 'notes':
        return Icons.description;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getTabDescription(String tabId) {
    switch (tabId) {
      case 'overview':
        return '查看待办事项、事件和笔记的摘要';
      case 'tasks':
        return '管理待办事项、事件和日历';
      case 'notes':
        return '编写和组织笔记';
      default:
        return '';
    }
  }

  Future<void> _selectTab(
    BuildContext context,
    WidgetRef ref,
    String tabId,
    String tabName,
  ) async {
    final notifier = ref.read(defaultTabNotifierProvider.notifier);
    await notifier.setDefaultTab(tabId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('默认标签已设为 $tabName'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              // This would need the previous tab value to implement properly
            },
          ),
        ),
      );
    }
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置为默认'),
        content: const Text(
          '这会将默认起始标签重置为任务。确定要继续吗？',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(defaultTabNotifierProvider.notifier);
      await notifier.resetToDefault();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('默认标签已重置为任务'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
