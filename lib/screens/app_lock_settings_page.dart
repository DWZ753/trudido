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

import '../services/app_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../utils/responsive_size.dart';
import '../theme/spacing_tokens.dart';
import '../utils/animated_navigation.dart';
import 'lock_screen.dart';
import '../widgets/common/common.dart';

/// Settings page for App Lock configuration
class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  bool _isEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  int _timeout = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await AppLockService.instance.isEnabled();
    final biometricEnabled = await AppLockService.instance.isBiometricEnabled();
    final biometricAvailable =
        await BiometricAuthService.isBiometricsAvailable();
    final timeout = await AppLockService.instance.getTimeout();

    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
        _timeout = timeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _enableAppLock() async {
    // Navigate to PIN setup
    final result = await AnimatedNavigation.push<bool>(
      context,
      const PinSetupScreen(
        title: '创建 PIN 码',
        subtitle: '解锁应用时需要此 PIN 码',
      ),
    );

    if (result == true) {
      await _loadSettings();

      // Ask about biometrics if available
      if (_biometricAvailable && mounted) {
        _showBiometricPrompt();
      }
    }
  }

  Future<void> _showBiometricPrompt() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 48),
        title: const Text('启用指纹解锁？'),
        content: const Text(
          '除了 PIN 码外，你是否还想使用指纹解锁应用？',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('启用'),
          ),
        ],
      ),
    );

    if (result == true) {
      await AppLockService.instance.setBiometricEnabled(true);
      await _loadSettings();
    }
  }

  Future<void> _disableAppLock() async {
    // Verify PIN first
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VerifyPinDialog(
        title: '验证 PIN 码',
        subtitle: '输入你的 PIN 码以禁用应用锁',
      ),
    );

    if (!mounted) return;
    if (verified == true) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('禁用应用锁？'),
          content: const Text(
            '这将移除应用的 PIN 码保护。任何能访问你设备的人都可以打开 Trudido。',
          ),
          actions: [
            ExpressiveTextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('禁用'),
            ),
          ],
        ),
      );

      if (result == true) {
        await AppLockService.instance.reset();
        await _loadSettings();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('应用锁已禁用')));
        }
      }
    }
  }

  Future<void> _changePin() async {
    // Verify current PIN first
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VerifyPinDialog(
        title: '当前 PIN 码',
        subtitle: '输入当前 PIN 码以继续',
      ),
    );

    if (verified == true && mounted) {
      // Navigate to new PIN setup
      await AnimatedNavigation.push<bool>(
        context,
        const PinSetupScreen(
          title: '新 PIN 码',
          subtitle: '输入新 PIN 码',
          isChangingPin: true,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 码更改成功')),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final success = await BiometricAuthService.authenticate(
        reason: '验证身份以启用指纹解锁',
      );

      if (success) {
        await AppLockService.instance.setBiometricEnabled(true);
        setState(() {
          _biometricEnabled = true;
        });
      }
    } else {
      await AppLockService.instance.setBiometricEnabled(false);
      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  Future<void> _changeTimeout() async {
    final options = AppLockService.timeoutOptions;

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '锁定超时',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '离开应用后多长时间锁定？',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((option) {
              final isSelected = option.seconds == _timeout;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, option.seconds),
              );
            }),
            SpacingGap.gapV8,
          ],
        ),
      ),
    );

    if (result != null) {
      await AppLockService.instance.setTimeout(result);
      setState(() {
        _timeout = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('应用锁')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Enable/Disable toggle
                SwitchListTile(
                  secondary: ScaledIcon(
                    Icons.lock_outline,
                    color: _isEnabled ? colorScheme.primary : null,
                  ),
                  title: const Text('启用应用锁'),
                  subtitle: Text(
                    _isEnabled
                        ? '需要 PIN 码才能打开应用'
                        : '使用 PIN 码保护应用',
                  ),
                  value: _isEnabled,
                  onChanged: (value) {
                    if (value) {
                      _enableAppLock();
                    } else {
                      _disableAppLock();
                    }
                  },
                ),

                if (_isEnabled) ...[
                  const Divider(),

                  // Change PIN
                  ListTile(
                    leading: const ScaledIcon(Icons.password),
                    title: const Text('更改 PIN 码'),
                    subtitle: const Text('更新你的解锁 PIN 码'),
                    trailing: const ScaledIcon(Icons.arrow_forward_ios),
                    onTap: _changePin,
                  ),

                  // Biometric toggle (if available)
                  if (_biometricAvailable)
                    SwitchListTile(
                      secondary: const ScaledIcon(Icons.fingerprint),
                      title: const Text('指纹解锁'),
                      subtitle: const Text('使用指纹解锁'),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),

                  // Lock timeout
                  ListTile(
                    leading: const ScaledIcon(Icons.timer_outlined),
                    title: const Text('锁定超时'),
                    subtitle: Text(AppLockService.getTimeoutLabel(_timeout)),
                    trailing: const ScaledIcon(Icons.arrow_forward_ios),
                    onTap: _changeTimeout,
                  ),

                  const Divider(),

                  // Info section
                  Padding(
                    padding: SpacingEdgeInsets.insets16,
                    child: Card(
                      child: Padding(
                        padding: SpacingEdgeInsets.insets16,
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                            ),
                            SpacingGap.gapH16,
                            Expanded(
                              child: Text(
                                '你的 PIN 码安全地存储在此设备上，绝不会发送到任何地方。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                if (!_isEnabled)
                  Padding(
                    padding: SpacingEdgeInsets.insets16,
                    child: Card(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      child: Padding(
                        padding: SpacingEdgeInsets.insets16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: colorScheme.primary,
                                ),
                                SpacingGap.gapH12,
                                Text(
                                  '保护你的数据',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SpacingGap.gapV12,
                            Text(
                              '启用应用锁后，访问任务和笔记前需要输入 PIN 码或使用指纹。即使他人拿到你已解锁的手机，也能增加一层隐私保护。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
