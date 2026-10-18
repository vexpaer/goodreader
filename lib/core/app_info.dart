/// Build-time application metadata.
///
/// The CI workflow passes these through `--dart-define` so the running APK knows
/// exactly which release it is, without pulling in a plugin.
library;

class AppInfo {
  const AppInfo._();

  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.6.0',
  );

  static const build = String.fromEnvironment(
    'APP_BUILD',
    defaultValue: '7',
  );

  static const repository = String.fromEnvironment(
    'APP_REPO',
    defaultValue: 'vexpaer/goodreader',
  );

  static const releasesUrl = 'https://github.com/$repository/releases';

  static const apiUrl = 'https://api.github.com/repos/$repository/releases/latest';

  static String get displayVersion => '$version+$build';
}
