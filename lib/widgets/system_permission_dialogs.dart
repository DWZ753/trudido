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
import '../services/system_settings_service.dart';
import '../services/navigation_service.dart';
import '../services/preferences_service.dart';
import '../widgets/common/common.dart';

Future<bool> showExactAlarmDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.canScheduleExactAlarms()) return true;
  if (!context.mounted) return false;
  final dialogContext = _bestDialogContext(context);
  if (!dialogContext.mounted) return false;
  final proceed = await showDialog<bool>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: const Text('启用精确闹钟'),
      content: const Text(
        '精确闹钟可确保提醒准时，即使在以下情况：\n'
        '- 设备空闲/深度休眠中\n'
        '- 过夜充电后\n'
        '- 短暂稍后提醒期间（5-15分钟）\n\n'
        'Android 需要手动开关。我们将打开系统设置；启用后返回即可。',
      ),
      actions: [
        ExpressiveTextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('打开设置'),
        ),
      ],
    ),
  );
  if (proceed == true) {
    await service.openExactAlarmSettings();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.canScheduleExactAlarms();
}

Future<bool> showBatteryOptimizationDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.isIgnoringBatteryOptimizations()) return true;
  // User previously chose "Don't show again" — skip the prompt
  if (PreferencesService().snapshot.dismissedBatteryOptimizationReminder) {
    return true;
  }
  if (!context.mounted) return false;
  final dialogContext = _bestDialogContext(context);
  if (!dialogContext.mounted) return false;
  // 0 = 'Later', 1 = 'Open Settings', 2 = 'Don\'t show again'
  final result = await showDialog<int>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: const Text('允许无限制后台运行'),
      content: const Text(
        '为防止系统延迟或取消提醒，请允许应用绕过电池优化。'
        '我们将打开系统屏幕；接受提示（或添加到白名单），然后返回此处。',
      ),
      actions: [
        ExpressiveTextButton(
          onPressed: () => Navigator.of(ctx).pop(2),
          child: const Text('不再显示'),
        ),
        ExpressiveTextButton(
          onPressed: () => Navigator.of(ctx).pop(0),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(1),
          child: const Text('打开设置'),
        ),
      ],
    ),
  );
  if (result == 2) {
    // Persist the user's choice to suppress future prompts
    await PreferencesService().update(
      dismissedBatteryOptimizationReminder: true,
    );
    return true;
  }
  if (result == 1) {
    await service.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.isIgnoringBatteryOptimizations();
}

/// Returns the best available BuildContext for showing a dialog.
/// Prefers NavigationService.context if it has MaterialLocalizations,
/// otherwise falls back to the provided context.
BuildContext _bestDialogContext(BuildContext fallback) {
  final ctx = NavigationService.context;
  if (ctx != null) {
    final has =
        Localizations.of<MaterialLocalizations>(ctx, MaterialLocalizations) !=
        null;
    if (has) return ctx;
  }
  return fallback;
}

Future<bool> showExactAlarmDialogIfNeededAuto() async {
  final ctx = NavigationService.navigatorKey.currentContext;
  if (ctx == null) return false;
  return showExactAlarmDialogIfNeeded(ctx);
}

Future<bool> showBatteryOptimizationDialogIfNeededAuto() async {
  final ctx = NavigationService.navigatorKey.currentContext;
  if (ctx == null) return false;
  return showBatteryOptimizationDialogIfNeeded(ctx);
}
