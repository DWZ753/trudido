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
import 'package:url_launcher/url_launcher.dart';
import '../config/flavor_config.dart';
import '../providers/app_providers.dart';
import '../providers/filter_providers.dart';
import '../utils/responsive_size.dart';
import 'about_screen.dart';
import 'personalization_screen.dart';
import 'comprehensive_notification_settings.dart';
import 'app_lock_settings_page.dart';
import 'data_management_screen.dart';
import 'experimental_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lazy ensure preferences initialized if user navigates directly before main init completes.
    final svc = ref.read(preferencesServiceProvider);
    if (!svc.isReady) {
      svc.ensureInitialized().then((_) {
        // Only update if still on settings screen.
        if (context.mounted) {
          ref.read(preferencesStateProvider.notifier).update(svc.snapshot);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(children: _buildFilteredSettings()),
    );
  }

  List<Widget> _buildFilteredSettings() {
    final List<Widget> allSettings = [
      // Appearance Section
      if (_matchesSearch(
        'appearance personalization profile colors layout visual preferences',
      )) ...[
        _buildSectionHeader(context, '外观'),
        _buildPersonalizationTile(),
      ],

      // Notifications & Alerts Section
      if (_matchesSearch(
        'notifications alerts permissions settings reliability',
      )) ...[
        _buildSectionHeader(context, '通知与提醒'),
        _buildNotificationsTile(),
      ],

      // Security Section
      if (_matchesSearch('security app lock pin fingerprint protect')) ...[
        _buildSectionHeader(context, '安全'),
        _buildAppLockTile(),
      ],

      // Data Management Section
      if (_matchesSearch('data management calendar sync import backup')) ...[
        _buildSectionHeader(context, '数据管理'),
        _buildDataManagementTile(),
      ],

      // About Section
      if (_matchesSearch('about licenses app license package repository')) ...[
        _buildSectionHeader(context, '关于'),
        _buildAboutTile(),
      ],

      // Support Section (FDroid only - hidden on PlayStore)
      if (FlavorConfig.showDonations &&
          _matchesSearch('support development buy coffee donate')) ...[
        _buildSectionHeader(context, '支持'),
        _buildSupportTile(),
      ],

      // Experimental Section
      if (_matchesSearch('experimental features try new')) ...[
        _buildSectionHeader(context, '实验性'),
        _buildExperimentalTile(),
      ],
    ];

    if (allSettings.isEmpty && _searchQuery.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '未找到设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请尝试不同的搜索词',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_searchQuery.isEmpty) {
      allSettings.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              '在欧洲用心打造 ❤️',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return allSettings;
  }

  bool _matchesSearch(String keywords) {
    if (_searchQuery.isEmpty) return true;
    return keywords.toLowerCase().contains(_searchQuery);
  }

  Widget _buildPersonalizationTile() {
    return ListTile(
      leading: ScaledIcon(Icons.palette_outlined),
      title: const Text('个性化'),
      subtitle: const Text('个人资料、颜色、布局和视觉偏好'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('personalization');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PersonalizationScreen(),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTile() {
    return ListTile(
      leading: ScaledIcon(Icons.notifications_outlined),
      title: const Text('通知'),
      subtitle: const Text('权限、设置和可靠性'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('notifications');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ComprehensiveNotificationSettings(),
          ),
        );
      },
    );
  }

  Widget _buildAppLockTile() {
    return ListTile(
      leading: ScaledIcon(Icons.lock_outline),
      title: const Text('应用锁'),
      subtitle: const Text('使用 PIN 码或指纹保护应用'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('app_lock');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
        );
      },
    );
  }

  Widget _buildDataManagementTile() {
    return ListTile(
      leading: ScaledIcon(Icons.storage_outlined),
      title: const Text('数据管理'),
      subtitle: const Text('日历同步、导入、备份和数据'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('data_management');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DataManagementScreen()),
        );
      },
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: ScaledIcon(Icons.info_outline),
      title: const Text('关于与许可证'),
      subtitle: const Text('应用许可证、软件包许可证和仓库'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('about');
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AboutScreen()));
      },
    );
  }

  Widget _buildSupportTile() {
    return ListTile(
      leading: ScaledIcon(Icons.favorite_outline),
      title: const Text('支持开发'),
      subtitle: const Text('请我喝杯咖啡或捐赠'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () => _showSupportSheet(context),
    );
  }

  Widget _buildExperimentalTile() {
    return ListTile(
      leading: ScaledIcon(Icons.science_outlined),
      title: const Text('实验性功能'),
      subtitle: const Text('尝试新的实验性功能'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        ref.read(recentSettingsProvider.notifier).record('experimental');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ExperimentalSettingsScreen(),
          ),
        );
      },
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

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '支持开发',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '如果你喜欢使用 Trudido，请考虑支持其开发！',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildDonationButton(
                context: ctx,
                label: '在 Ko-fi 上支持',
                icon: Icons.coffee_outlined,
                url: 'https://ko-fi.com/dominikmuellr',
                color: const Color(0xFFFF5E5B),
              ),
              const SizedBox(height: 12),
              _buildDonationButton(
                context: ctx,
                label: '在 Liberapay 上捐赠',
                icon: Icons.favorite_outline,
                url: 'https://liberapay.com/dominikmuellr/donate',
                color: const Color(0xFFF6C915),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String url,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            // URL couldn't be launched
          }
        },
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
