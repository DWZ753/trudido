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

class EditorSettingsScreen extends ConsumerWidget {
  const EditorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑器'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          spacing.gapV8,

          // Font
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            leading: const Icon(Icons.edit_note),
            title: const Text('字体'),
            subtitle: Text(_getEditorFontDisplayName(prefs.editorFontFamily)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontPicker(context, ref),
          ),

          // Font Size
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            leading: const Icon(Icons.format_size),
            title: const Text('字体大小'),
            subtitle: Text('${prefs.editorFontSize.toStringAsFixed(0)} pt'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontSizePicker(context, ref),
          ),

          // Line Spacing
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            leading: const Icon(Icons.format_line_spacing),
            title: const Text('行间距'),
            subtitle: Text('${prefs.lineHeightMultiplier.toStringAsFixed(1)}×'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLineSpacingPicker(context, ref),
          ),

          // Paragraph Spacing
          ListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            leading: const Icon(Icons.space_bar_outlined),
            title: const Text('段落间距'),
            subtitle: Text(
              prefs.paragraphSpacing == 0
                  ? '无'
                  : '${prefs.paragraphSpacing.toStringAsFixed(0)} pt',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showParagraphSpacingPicker(context, ref),
          ),

          // Auto-Open Keyboard
          SwitchListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            secondary: const Icon(Icons.keyboard_outlined),
            title: const Text('自动打开键盘'),
            subtitle: const Text(
              '打开笔记时自动显示键盘',
            ),
            value: prefs.autoOpenKeyboardInNotes,
            onChanged: (_) => controller.toggleAutoOpenKeyboardInNotes(),
          ),

          // Default Read Mode
          SwitchListTile(
            contentPadding: spacing.listTileInsets,
            visualDensity: spacing.listTileDensity,
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('默认为阅读模式'),
            subtitle: const Text(
              '默认以阅读模式打开笔记（每个笔记会记住上次的模式）',
            ),
            value: prefs.defaultNoteReadMode,
            onChanged: (_) => controller.toggleDefaultNoteReadMode(),
          ),

          spacing.gapV16,
        ],
      ),
    );
  }

  String _getEditorFontDisplayName(String key) {
    switch (key) {
      case 'inter':
        return 'Inter';
      case 'roboto':
        return 'Roboto';
      case 'opensans':
        return 'Open Sans';
      case 'lexend':
        return 'Lexend';
      case 'jetbrains':
        return 'JetBrains Mono';
      case 'monospace':
        return 'Monospace';
      default:
        return '默认（应用字体）';
    }
  }

  void _showFontPicker(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider);
    final currentFont = ref.read(preferencesStateProvider).editorFontFamily;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          _fontOption(
            ctx,
            controller,
            currentFont,
            'default',
            'Default (app font)',
            '与应用全局字体相同',
            Icons.font_download_outlined,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'inter',
            'Inter',
            '现代几何UI字体',
            Icons.text_fields,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'roboto',
            'Roboto',
            'Material 默认',
            Icons.android,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'lexend',
            'Lexend',
            '增强可读性',
            Icons.visibility,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'opensans',
            'Open Sans',
            '简洁中性',
            Icons.font_download,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'jetbrains',
            'JetBrains Mono',
            '代码与技术',
            Icons.code,
          ),
          _fontOption(
            ctx,
            controller,
            currentFont,
            'monospace',
            'Monospace',
            '系统等宽字体',
            Icons.space_bar,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _fontOption(
    BuildContext context,
    dynamic controller,
    String currentFont,
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return RadioListTile<String>(
      value: value,
      // ignore: deprecated_member_use
      groupValue: currentFont,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      // ignore: deprecated_member_use
      onChanged: (v) {
        if (v != null) {
          controller.setEditorFontFamily(v);
          Navigator.pop(context);
        }
      },
    );
  }

  void _showFontSizePicker(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider);
    double current = ref.read(preferencesStateProvider).editorFontSize;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('字体大小', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '敏捷的棕色狐狸跳过了懒惰的狗',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: current,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  Expanded(
                    child: Slider(
                      value: current,
                      min: 12.0,
                      max: 24.0,
                      divisions: 12,
                      label: '${current.toStringAsFixed(0)} pt',
                      onChanged: (v) {
                        setState(() => current = v);
                        controller.setEditorFontSize(v);
                      },
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 24),
                ],
              ),
              Center(
                child: Text(
                  '${current.toStringAsFixed(0)} pt',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLineSpacingPicker(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider);
    final current = ref.read(preferencesStateProvider).lineHeightMultiplier;
    const options = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => RadioGroup<double>(
        groupValue: current,
        onChanged: (picked) {
          if (picked != null) {
            controller.setLineHeightMultiplier(picked);
            Navigator.pop(ctx);
          }
        },
        child: ListView(
          shrinkWrap: true,
          children: [
            ...options.map(
              (v) => RadioListTile<double>(
                value: v,
                title: Text('${v.toStringAsFixed(1)}×'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showParagraphSpacingPicker(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider);
    final current = ref.read(preferencesStateProvider).paragraphSpacing;
    const options = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => RadioGroup<double>(
        groupValue: current,
        onChanged: (picked) {
          if (picked != null) {
            controller.setParagraphSpacing(picked);
            Navigator.pop(ctx);
          }
        },
        child: ListView(
          shrinkWrap: true,
          children: [
            ...options.map(
              (v) => RadioListTile<double>(
                value: v,
                title: Text(
                  v == 0 ? '无（0 pt）' : '${v.toStringAsFixed(0)} pt',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
