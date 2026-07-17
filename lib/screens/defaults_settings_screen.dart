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
import 'home_screen_notifiers.dart';
import '../services/preferences_service.dart';
import '../services/privacy_service.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../repositories/note_folder_repository.dart';
import '../utils/week_start_utils.dart';
import '../theme/spacing_tokens.dart';

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
      // Attempt to reload the current setting after error
      _loadCurrentTab();
    }
  }
}

class DefaultsSettingsScreen extends ConsumerWidget {
  const DefaultsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('默认设置'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          spacing.gapV8,
          const _OverviewTabSelector(),
          const _DefaultTabSelector(),
          const _DefaultViewSelector(),
          const _DefaultNotesFolderSelector(),
          const _CompactNotesViewSelector(),
          const _TimeFormatSelector(),
          const _WeekStartSelector(),
          const _GreetingLanguageSelector(),
          const _ContrastLevelSelector(),
          const _CompactModeSelector(),
          const _NavLabelsSelector(),
          const _SwipeActionsSelector(),
          const _BlackoutRecentsSelector(),
          spacing.gapV16,
        ],
      ),
    );
  }
}

// ============================================================================
// Overview Tab Selector
// ============================================================================

class _OverviewTabSelector extends ConsumerWidget {
  const _OverviewTabSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return SwitchListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      secondary: const Icon(Icons.home_outlined),
      title: const Text('显示概览标签'),
      subtitle: const Text('在导航栏中显示概览标签'),
      value: preferences.showOverviewTab,
      onChanged: (_) => controller.toggleShowOverviewTab(),
    );
  }
}

// ============================================================================
// Default Tab Selector
// ============================================================================

class _DefaultTabSelector extends ConsumerWidget {
  const _DefaultTabSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTabAsync = ref.watch(defaultTabNotifierProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return defaultTabAsync.when(
      loading: () => ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: const Icon(Icons.home_outlined),
        title: const Text('默认起始标签'),
        subtitle: const Text('加载中...'),
      ),
      error: (error, _) => ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: const Icon(Icons.error_outline),
        title: const Text('默认起始标签'),
        subtitle: const Text('加载设置出错'),
      ),
      data: (currentTab) {
        final tabs = DefaultTabService.getAllTabs();
        final currentTabName = tabs[currentTab] ?? '未知';

        return ListTile(
          contentPadding: spacing.listTileInsets,
          visualDensity: spacing.listTileDensity,
          leading: const Icon(Icons.home_outlined),
          title: const Text('默认起始标签'),
          subtitle: Text(currentTabName),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (ctx) {
                return _DefaultTabSheet(current: currentTab);
              },
            );
            if (choice != null) {
              final notifier = ref.read(defaultTabNotifierProvider.notifier);
              await notifier.setDefaultTab(choice);
              // Also switch to the selected tab immediately
              final tabIndex = DefaultTabService.tabIndices[choice] ?? 0;
              ref.read(currentTabProvider.notifier).setTab(tabIndex);
            }
          },
        );
      },
    );
  }
}

class _DefaultTabSheet extends ConsumerWidget {
  final String current;
  const _DefaultTabSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tabs = DefaultTabService.getAllTabs();
    final prefs = ref.watch(preferencesStateProvider);
    final hideBottomNav = prefs.hideBottomNavigation;
    final showOverviewTab = prefs.showOverviewTab;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildOption(String tabId, String tabName, IconData icon) {
      final selected = current == tabId;
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          tabName,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, tabId),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          ...tabs.entries
              .where((e) => showOverviewTab || e.key != 'overview')
              .map((entry) {
                return buildOption(
                  entry.key,
                  entry.value,
                  _getTabIcon(entry.key),
                );
              }),
          const Divider(height: 12),
          SwitchListTile.adaptive(
            contentPadding: spacing.insetsH16,
            secondary: const Icon(Icons.view_agenda_outlined),
            title: const Text('显示底部导航'),
            subtitle: const Text('隐藏底部标签栏和导航轨道'),
            value: !hideBottomNav,
            onChanged: (value) async {
              final prefsService = PreferencesService();
              final updated = await prefsService.update(
                hideBottomNavigation: !value,
              );
              ref.read(preferencesStateProvider.notifier).update(updated);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tabId) {
    switch (tabId) {
      case 'overview':
        return Icons.dashboard_outlined;
      case 'tasks':
        return Icons.checklist;
      case 'notes':
        return Icons.notes_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

// ============================================================================
// Default View Selector
// ============================================================================

class _DefaultViewSelector extends ConsumerWidget {
  const _DefaultViewSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultView = ref.watch(preferencesStateProvider).defaultTaskView;
    final viewName = defaultView == 'calendar' ? '日历' : '列表';
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.view_list_outlined),
      title: const Text('默认任务视图'),
      subtitle: Text(viewName),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _DefaultViewSheet(current: defaultView);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setDefaultTaskView(choice);
        }
      },
    );
  }
}

class _DefaultViewSheet extends ConsumerWidget {
  final String current;

  const _DefaultViewSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return ListView(
      shrinkWrap: true,
      children: [
        _buildOption(context, ref, 'list', '列表', Icons.list),
        _buildOption(
          context,
          ref,
          'calendar',
          '日历',
          Icons.calendar_month,
        ),
        SizedBox(height: spacing.s16),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    WidgetRef ref,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = value == current;
    final theme = Theme.of(context);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

// ============================================================================
// Default Notes Folder Selector
// ============================================================================

class _DefaultNotesFolderSelector extends ConsumerWidget {
  const _DefaultNotesFolderSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultFolderId = ref
        .watch(preferencesStateProvider)
        .defaultNotesFolderId;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return foldersAsync.when(
      data: (folders) {
        String displayName;
        if (defaultFolderId == null) {
          displayName = '所有笔记';
        } else if (defaultFolderId == 'UNFILED') {
          displayName = '未归档笔记';
        } else {
          final folder = folders
              .where((f) => f.id == defaultFolderId)
              .firstOrNull;
          displayName = folder?.name ?? '所有笔记';
        }

        return ListTile(
          contentPadding: spacing.listTileInsets,
          visualDensity: spacing.listTileDensity,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('默认笔记视图'),
          subtitle: Text(displayName),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () async {
            final choice = await showModalBottomSheet<String?>(
              context: context,
              showDragHandle: true,
              builder: (ctx) {
                return _DefaultNotesFolderSheet(
                  current: defaultFolderId,
                  folders: folders,
                );
              },
            );
            if (choice != null || choice == 'CLEAR') {
              final controller = ref.read(preferencesControllerProvider);
              await controller.setDefaultNotesFolder(
                choice == 'CLEAR' ? null : choice,
              );
            }
          },
        );
      },
      loading: () => ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: const Icon(Icons.folder_outlined),
        title: const Text('默认笔记视图'),
        subtitle: const Text('加载中...'),
      ),
      error: (_, _) => ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: const Icon(Icons.folder_outlined),
        title: const Text('默认笔记视图'),
        subtitle: const Text('所有笔记'),
      ),
    );
  }
}

class _DefaultNotesFolderSheet extends ConsumerWidget {
  final String? current;
  final List folders;

  const _DefaultNotesFolderSheet({
    required this.current,
    required this.folders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildOption(
      String? folderId,
      String name,
      IconData icon,
      AdaptiveSpacing spacing,
    ) {
      final selected = current == folderId;
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          name,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, folderId ?? 'CLEAR'),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: spacing.s4),
            // All Notes option
            buildOption(null, '所有笔记', Icons.folder_outlined, spacing),
            // Unfiled Notes option
            buildOption('UNFILED', '未归档笔记', Icons.folder_open, spacing),
            if (folders.isNotEmpty) const Divider(),
            // Individual folders (exclude vault folders)
            ...folders.where((f) => !f.isVault).map((folder) {
              return buildOption(folder.id, folder.name, Icons.folder, spacing);
            }),
            SizedBox(height: spacing.s16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Compact Notes View Selector
// ============================================================================

class _CompactNotesViewSelector extends ConsumerWidget {
  const _CompactNotesViewSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return SwitchListTile.adaptive(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      secondary: const Icon(Icons.title),
      title: const Text('紧凑笔记视图'),
      subtitle: const Text(
        '在笔记列表中仅显示标题，隐藏内容预览',
      ),
      value: preferences.compactNotesView,
      onChanged: (_) async {
        await controller.toggleCompactNotesView();
      },
    );
  }
}

// ============================================================================
// Week Start Selector
// ============================================================================

class _WeekStartSelector extends ConsumerWidget {
  const _WeekStartSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final currentDay = prefs.firstDayOfWeek;
    final dayName = WeekStartUtils.getDayName(currentDay);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.calendar_view_week_outlined),
      title: const Text('周起始日'),
      subtitle: Text(dayName),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _WeekStartSheet(current: currentDay);
          },
        );
        if (choice != null) {
          controller.setFirstDayOfWeek(choice);
        }
      },
    );
  }
}

class _WeekStartSheet extends ConsumerWidget {
  final int current;
  const _WeekStartSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildOption(int dayIndex) {
      final selected = current == dayIndex;
      final dayName = WeekStartUtils.getDayName(dayIndex);
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(
          Icons.today,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(
          dayName,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, dayIndex),
      );
    }

    final commonDays = [0, 1, 6]; // Sunday, Monday, Saturday
    final otherDays = [2, 3, 4, 5]; // Tue-Fri

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.s16,
                spacing.s8,
                spacing.s16,
                spacing.s8,
              ),
              child: Text(
                '常用',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            ...commonDays.map(buildOption),
            const Divider(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.s16,
                spacing.s8,
                spacing.s16,
                spacing.s8,
              ),
              child: Text(
                '其他',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            ...otherDays.map(buildOption),
            SizedBox(height: spacing.s16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Greeting Language Selector
// ============================================================================

class _GreetingLanguageSelector extends ConsumerWidget {
  const _GreetingLanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.translate),
      title: const Text('问候语言'),
      subtitle: Text(_getGreetingLanguageName(preferences.greetingLanguage)),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return _GreetingLanguageSheet(
                  scrollController: scrollController,
                );
              },
            );
          },
        );
      },
    );
  }

  String _getGreetingLanguageName(int index) {
    const greetings = [
      'English',
      'Español',
      'Français',
      'Deutsch',
      'Italiano',
      'Nederlands',
      'Português',
      'Svenska',
      'Dansk',
      'Norsk',
      'Suomi',
      'Polski',
      'Čeština',
      'Magyar',
      'Română',
      'Türkçe',
      'Українська',
    ];
    if (index >= 0 && index < greetings.length) {
      return greetings[index];
    }
    return 'English';
  }
}

// ============================================================================
// Greeting Language Sheet
// ============================================================================

class _GreetingLanguageSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _GreetingLanguageSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    final languages = [
      'English',
      'Español',
      'Français',
      'Deutsch',
      'Italiano',
      'Nederlands',
      'Português',
      'Svenska',
      'Dansk',
      'Norsk',
      'Suomi',
      'Polski',
      'Čeština',
      'Magyar',
      'Română',
      'Türkçe',
      'Українська',
    ];

    return SafeArea(
      child: ListView.builder(
        controller: scrollController,
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final isSelected = preferences.greetingLanguage == index;
          return ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            title: Text(languages[index]),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.setGreetingLanguage(index);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// Swipe Actions Selector
// ============================================================================

String _getSwipeActionName(String action) {
  switch (action) {
    case 'delete':
      return '删除';
    case 'pin':
      return '置顶';
    case 'none':
      return '无';
    default:
      return '未知';
  }
}

class _SwipeActionsSelector extends ConsumerWidget {
  const _SwipeActionsSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.swipe),
      title: const Text('滑动操作'),
      subtitle: Text(
        '左滑：${_getSwipeActionName(preferences.swipeLeftAction)}，右滑：${_getSwipeActionName(preferences.swipeRightAction)}',
      ),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => const _SwipeActionSheet(),
        );
      },
    );
  }
}

class _SwipeActionSheet extends ConsumerWidget {
  const _SwipeActionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final cs = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildActionOption(
      String action,
      String label,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
    ) {
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(
          icon,
          color: isSelected ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : null),
        ),
        trailing: isSelected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: onTap,
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.s16),
            child: Text(
              '配置滑动操作',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            title: const Text('左滑操作'),
            subtitle: Text(_getSwipeActionName(preferences.swipeLeftAction)),
          ),
          buildActionOption(
            'delete',
            '删除',
            Icons.delete_outline,
            preferences.swipeLeftAction == 'delete',
            () {
              controller.setSwipeLeftAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            '置顶',
            Icons.push_pin_outlined,
            preferences.swipeLeftAction == 'pin',
            () {
              controller.setSwipeLeftAction('pin');
            },
          ),
          buildActionOption(
            'none',
            '无',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeLeftAction == 'none',
            () {
              controller.setSwipeLeftAction('none');
            },
          ),
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            title: const Text('右滑操作'),
            subtitle: Text(_getSwipeActionName(preferences.swipeRightAction)),
          ),
          buildActionOption(
            'delete',
            '删除',
            Icons.delete_outline,
            preferences.swipeRightAction == 'delete',
            () {
              controller.setSwipeRightAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            '置顶',
            Icons.push_pin_outlined,
            preferences.swipeRightAction == 'pin',
            () {
              controller.setSwipeRightAction('pin');
            },
          ),
          buildActionOption(
            'none',
            '无',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeRightAction == 'none',
            () {
              controller.setSwipeRightAction('none');
            },
          ),
          SizedBox(height: spacing.s16),
        ],
      ),
    );
  }
}

// ============================================================================
// Time Format Selector
// ============================================================================

class _TimeFormatSelector extends ConsumerWidget {
  const _TimeFormatSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final currentFormat = prefs.timeFormat;
    final formatName = _getFormatName(currentFormat, context);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.schedule_outlined),
      title: const Text('时间格式'),
      subtitle: Text(formatName),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _TimeFormatSheet(current: currentFormat);
          },
        );
        if (choice != null) {
          controller.setTimeFormat(choice);
        }
      },
    );
  }

  String _getFormatName(String format, BuildContext context) {
    switch (format) {
      case '12h':
        return '12 小时制（下午 3:30）';
      case '24h':
        return '24 小时制（15:30）';
      default:
        final system24 = MediaQuery.of(context).alwaysUse24HourFormat;
        return '系统默认（${system24 ? '24 小时制' : '12 小时制'}）';
    }
  }
}

class _TimeFormatSheet extends ConsumerWidget {
  final String current;
  const _TimeFormatSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildOption(
      String value,
      String label,
      String example,
      IconData icon,
    ) {
      final selected = current == value;
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        subtitle: Text(example),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, value),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildOption(
            'system',
            '系统默认',
            MediaQuery.of(context).alwaysUse24HourFormat
                ? '当前：24 小时制'
                : '当前：12 小时制',
            Icons.settings_outlined,
          ),
          buildOption('12h', '12 小时制', '下午 3:30', Icons.schedule_outlined),
          buildOption('24h', '24 小时制', '15:30', Icons.schedule_outlined),
          SizedBox(height: spacing.s16),
        ],
      ),
    );
  }
}

// ============================================================================
// Contrast Level Selector (Material 3 January 2026)
// ============================================================================

class _ContrastLevelSelector extends ConsumerWidget {
  const _ContrastLevelSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final currentLevel = prefs.contrastLevel;
    final spacing = ref.watch(adaptiveSpacingProvider);

    String getDisplayName(String level) {
      switch (level) {
        case 'medium':
          return '中等';
        case 'high':
          return '高';
        case 'standard':
        default:
          return '标准';
      }
    }

    return ListTile(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      leading: const Icon(Icons.contrast),
      title: const Text('对比度'),
      subtitle: Text(getDisplayName(currentLevel)),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _ContrastLevelSheet(current: currentLevel);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setContrastLevel(choice);
        }
      },
    );
  }
}

class _ContrastLevelSheet extends ConsumerWidget {
  final String current;
  const _ContrastLevelSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    Widget buildOption(String level, String label, String desc, IconData icon) {
      final selected = current == level;
      return ListTile(
        contentPadding: spacing.listTileInsets,
        visualDensity: spacing.listTileDensity,
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        subtitle: Text(desc),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.of(context).pop(level),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.s24,
              spacing.s8,
              spacing.s24,
              spacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '对比度级别',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: spacing.s4),
                Text(
                  '调整颜色对比度以获得更好的可见性',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          buildOption(
            'standard',
            '标准',
            '适合大多数用户的默认对比度',
            Icons.contrast,
          ),
          buildOption(
            'medium',
            '中等',
            '增强对比度以提高可读性',
            Icons.contrast_outlined,
          ),
          buildOption(
            'high',
            '高',
            '适合无障碍需求的最大对比度',
            Icons.accessibility_new,
          ),
          SizedBox(height: spacing.s16),
        ],
      ),
    );
  }
}

// ============================================================================
// Nav Labels Selector
// ============================================================================

class _NavLabelsSelector extends ConsumerWidget {
  const _NavLabelsSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return SwitchListTile.adaptive(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      secondary: const Icon(Icons.label_off_outlined),
      title: const Text('隐藏导航标签'),
      subtitle: const Text('在底部导航栏仅显示图标'),
      value: preferences.hideNavLabels,
      onChanged: (_) => controller.toggleHideNavLabels(),
    );
  }
}

// ============================================================================
// Compact Mode Selector
// ============================================================================

class _CompactModeSelector extends ConsumerWidget {
  const _CompactModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return SwitchListTile.adaptive(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      secondary: const Icon(Icons.density_medium),
      title: const Text('紧凑模式'),
      subtitle: const Text(
        '间距减少 35%，字号减少 15%，以容纳更多内容',
      ),
      value: preferences.compactDensity,
      onChanged: (value) async {
        await controller.toggleCompactDensity();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? '紧凑模式已启用' : '紧凑模式已禁用',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}

// ============================================================================
// Blackout Recents Selector
// ============================================================================

class _BlackoutRecentsSelector extends ConsumerWidget {
  const _BlackoutRecentsSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return SwitchListTile.adaptive(
      contentPadding: spacing.listTileInsets,
      visualDensity: spacing.listTileDensity,
      secondary: const Icon(Icons.security),
      title: const Text('隐藏最近任务'),
      subtitle: const Text('在 Android 最近任务中隐藏应用内容以保护隐私'),
      value: preferences.blackoutRecents,
      onChanged: (value) async {
        await controller.toggleBlackoutRecents();

        if (context.mounted) {
          final privacyService = PrivacyService();
          final newValue = ref.read(preferencesStateProvider).blackoutRecents;
          await privacyService.setSecureFlag(newValue);
        }
      },
    );
  }
}
