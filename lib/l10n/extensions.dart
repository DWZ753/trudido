import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Convenience extension for accessing localized strings.
extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
