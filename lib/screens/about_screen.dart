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
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';
import '../widgets/changelog_dialog.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _licenseText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    try {
      final text = await rootBundle.loadString('LICENSE');
      if (mounted) {
        setState(() {
          _licenseText = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _licenseText = '未找到许可证文件。';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openGitHub() async {
    const url = 'https://github.com/dominikmuellr/trudido';
    final uri = Uri.parse(url);
    // Open in external browser app (not in-app webview)
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开 URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于与许可证')),
      body: ListView(
        children: [
          // App Information Section
          _buildSectionHeader(context, '应用信息'),
          ListTile(
            leading: Icon(Icons.info_outline, color: cs.primary),
            title: const Text('应用名称'),
            subtitle: const Text('Trudido'),
          ),
          ListTile(
            leading: Icon(Icons.tag, color: cs.primary),
            title: const Text('版本'),
            subtitle: const Text('v1.3.5'),
          ),
          ListTile(
            leading: Icon(Icons.code, color: cs.primary),
            title: const Text('GitHub 仓库'),
            subtitle: const Text('查看源代码并参与贡献'),
            trailing: Icon(
              Icons.open_in_new,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: _openGitHub,
          ),
          ListTile(
            leading: Icon(Icons.new_releases_outlined, color: cs.primary),
            title: const Text('更新日志'),
            subtitle: const Text('每个版本的新内容'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => showChangelogDialog(context),
          ),

          // Licenses Section
          _buildSectionHeader(context, '许可证'),
          ListTile(
            leading: Icon(Icons.article_outlined, color: cs.primary),
            title: const Text('应用许可证'),
            subtitle: const Text('GPL-3.0 - 查看完整许可证文本'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: _showLicenseDialog,
          ),
          ListTile(
            leading: Icon(Icons.list, color: cs.primary),
            title: const Text('软件包许可证'),
            subtitle: const Text('查看所有依赖的许可证'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Trudido',
              applicationVersion: 'v1.3.5',
            ),
          ),

          // Packages Section
          _buildSectionHeader(context, '核心软件包'),
          _buildPackageTile('State Management', 'flutter_riverpod', '^3.2.1'),
          _buildPackageTile('Local Database', 'hive', '^2.2.3'),
          _buildPackageTile('Hive Flutter', 'hive_flutter', '^1.1.0'),
          _buildPackageTile(
            'Shared Preferences',
            'shared_preferences',
            '^2.3.2',
          ),
          _buildPackageTile('Path Provider', 'path_provider', '^2.1.4'),
          _buildPackageTile('Path Utilities', 'path', '^1.9.0'),

          _buildSectionHeader(context, 'UI 与工具'),
          _buildPackageTile('Material You Colors', 'dynamic_color', '^1.8.1'),
          _buildPackageTile('Slidable Widgets', 'flutter_slidable', '^4.0.1'),
          _buildPackageTile('Calendar', 'table_calendar', '^3.1.2'),
          _buildPackageTile(
            'Staggered Grid',
            'flutter_staggered_grid_view',
            '^0.7.0',
          ),
          _buildPackageTile(
            'Markdown Rendering',
            'flutter_markdown_plus',
            '^1.0.7',
          ),
          _buildPackageTile('Rich Text Editor', 'flutter_quill', '^11.5.0'),
          _buildPackageTile('URL Launcher', 'url_launcher', '^6.1.10'),
          _buildPackageTile('Internationalization', 'intl', '^0.20.2'),
          _buildPackageTile('UUID Generator', 'uuid', '^4.5.0'),
          _buildPackageTile('Cupertino Icons', 'cupertino_icons', '^1.0.8'),
          _buildPackageTile('Meta Annotations', 'meta', '^1.16.0'),
          _buildPackageTile('Color Picker', 'flex_color_picker', '^3.7.2'),
          _buildPackageTile('Share Plus', 'share_plus', '^12.0.1'),

          _buildSectionHeader(context, '媒体与文件'),
          _buildPackageTile('File Picker', 'file_picker', '^10.3.10'),
          _buildPackageTile('Image Picker', 'image_picker', '^1.1.2'),
          _buildPackageTile('Video Player', 'video_player', '^2.9.2'),
          _buildPackageTile(
            'Video Thumbnails',
            'fc_native_video_thumbnail',
            '^0.17.2',
          ),
          _buildPackageTile('Audio Recording', 'record', '^6.2.0'),
          _buildPackageTile('Audio Playback', 'audioplayers', '^6.0.0'),
          _buildPackageTile('PDF Generation', 'pdf', '^3.11.1'),
          _buildPackageTile('PDF Printing', 'printing', '^5.13.4'),

          _buildSectionHeader(context, '安全与集成'),
          _buildPackageTile('Encryption', 'encrypt', '^5.0.3'),
          _buildPackageTile(
            'Secure Storage',
            'flutter_secure_storage',
            '^10.0.0',
          ),
          _buildPackageTile('Biometric Auth', 'local_auth', '^3.0.0'),
          _buildPackageTile('Cryptography', 'crypto', '^3.0.3'),
          _buildPackageTile('Permissions', 'permission_handler', '^12.0.1'),
          _buildPackageTile(
            'Calendar Integration',
            'device_calendar_plus',
            '^0.3.3',
          ),

          SpacingGap.gapV16,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '在欧洲用心打造 ❤️',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SpacingGap.gapV16,
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPackageTile(String name, String packageName, String version) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        Icons.extension_outlined,
        color: theme.colorScheme.tertiary,
        size: 20,
      ),
      title: Text(name),
      subtitle: Text('$packageName $version', style: theme.textTheme.bodySmall),
      dense: true,
    );
  }

  void _showLicenseDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('许可证（GPL-3.0）'),
        content: SizedBox(
          width: double.maxFinite,
          child: _loading
              ? const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(child: Text(_licenseText)),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
