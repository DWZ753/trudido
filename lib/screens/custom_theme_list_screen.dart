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
import '../models/custom_theme.dart';
import '../services/storage_service.dart';
import '../controllers/preferences_controller.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';
import '../theme/spacing_tokens.dart';
import 'custom_theme_editor_screen.dart';

/// Screen that lists all saved custom themes, allowing users to create,
/// activate, edit, duplicate, and delete themes.
class CustomThemeListScreen extends ConsumerStatefulWidget {
  const CustomThemeListScreen({super.key});

  @override
  ConsumerState<CustomThemeListScreen> createState() =>
      _CustomThemeListScreenState();
}

class _CustomThemeListScreenState extends ConsumerState<CustomThemeListScreen> {
  List<CustomTheme> _themes = [];
  String? _activeThemeId;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  void _loadThemes() {
    final jsonStrings = StorageService.getAllCustomThemes();
    _themes = jsonStrings
        .map((s) {
          try {
            return CustomTheme.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<CustomTheme>()
        .toList();
    _themes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    _activeThemeId = ref.read(preferencesStateProvider).activeCustomThemeId;
  }

  /// Bump the revision counter so main.dart reloads the custom theme from storage.
  void _bumpThemeRevision() {
    final current = ref.read(customThemeRevisionProvider);
    ref.read(customThemeRevisionProvider.notifier).update(current + 1);
  }

  Future<void> _createNewTheme() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomThemeEditorScreen()),
    );
    if (result == true) {
      _bumpThemeRevision();
      setState(_loadThemes);
    }
  }

  Future<void> _editTheme(CustomTheme theme) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomThemeEditorScreen(existingTheme: theme),
      ),
    );
    if (result == true) {
      _bumpThemeRevision();
      setState(_loadThemes);
    }
  }

  Future<void> _activateTheme(String id) async {
    final controller = ref.read(preferencesControllerProvider);
    await controller.setActiveCustomTheme(id);
    setState(() => _activeThemeId = id);
  }

  Future<void> _deactivateTheme() async {
    final controller = ref.read(preferencesControllerProvider);
    await controller.clearActiveCustomTheme();
    setState(() => _activeThemeId = null);
  }

  Future<void> _duplicateTheme(CustomTheme theme) async {
    final newTheme = theme.duplicate(
      newId: DateTime.now().millisecondsSinceEpoch.toString(),
      newName: '${theme.name} (副本)',
    );
    await StorageService.saveCustomTheme(newTheme.id, newTheme.toJsonString());
    setState(_loadThemes);
  }

  Future<void> _deleteTheme(CustomTheme theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除主题？'),
        content: Text('删除"${theme.name}"？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // If deleting the active theme, deactivate first
      if (theme.id == _activeThemeId) {
        await ref.read(preferencesControllerProvider).clearActiveCustomTheme();
      }
      await StorageService.deleteCustomTheme(theme.id);
      setState(_loadThemes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('自定义主题')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTheme,
        icon: const Icon(Icons.add),
        label: const Text('创建主题'),
      ),
      body: _themes.isEmpty
          ? _buildEmptyState(theme, colorScheme)
          : _buildThemeList(theme, colorScheme),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            SpacingGap.gapV16,
            Text(
              '暂无自定义主题',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            SpacingGap.gapV8,
            Text(
              '创建完全控制每种颜色的自定义主题，或从朋友处导入。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _themes.length,
      itemBuilder: (context, index) {
        final customTheme = _themes[index];
        final isActive = customTheme.id == _activeThemeId;
        return _buildThemeCard(customTheme, isActive, theme, colorScheme);
      },
    );
  }

  Widget _buildThemeCard(
    CustomTheme customTheme,
    bool isActive,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Build preview color scheme
    final lightScheme = customTheme.buildColorScheme(Brightness.light);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editTheme(customTheme),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customTheme.name.isEmpty ||
                                  customTheme.name == '未命名主题'
                              ? customTheme.generateAutoName()
                              : customTheme.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customTheme.name.isEmpty ||
                            customTheme.name == '未命名主题')
                          Text(
                            '根据颜色自动命名',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Activation toggle switch
                  Switch(
                    value: isActive,
                    onChanged: (value) async {
                      if (value) {
                        await _activateTheme(customTheme.id);
                      } else {
                        await _deactivateTheme();
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _editTheme(customTheme);
                          break;
                        case 'duplicate':
                          _duplicateTheme(customTheme);
                          break;
                        case 'delete':
                          _deleteTheme(customTheme);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('编辑'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('复制'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: colorScheme.error),
                          title: Text(
                            '删除',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SpacingGap.gapV8,

              // Color preview - show user's 3 chosen colors
              Row(
                children: [
                  Text(
                    '颜色：',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _colorSwatchLarge(lightScheme.primary, '基础色'),
                  _colorSwatchLarge(lightScheme.secondary, '增强色'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorSwatchLarge(Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
