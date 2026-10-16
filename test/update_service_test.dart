import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/update_service.dart';

void main() {
  group('VersionNumber', () {
    test('parses a tag with a leading v', () {
      expect(VersionNumber.parse('v1.2.3').parts, [1, 2, 3]);
    });

    test('pads missing components', () {
      expect(VersionNumber.parse('2.1').parts, [2, 1, 0]);
      expect(VersionNumber.parse('3').parts, [3, 0, 0]);
    });

    test('ignores build metadata and pre-release suffixes', () {
      expect(VersionNumber.parse('0.2.0+2').parts, [0, 2, 0]);
      expect(VersionNumber.parse('1.0.0-beta.1').parts, [1, 0, 0]);
    });

    test('compares numerically, not lexically', () {
      expect(
        VersionNumber.parse('0.10.0') > VersionNumber.parse('0.9.0'),
        isTrue,
      );
      expect(
        VersionNumber.parse('1.0.0') > VersionNumber.parse('1.0.0'),
        isFalse,
      );
      expect(
        VersionNumber.parse('2.0') > VersionNumber.parse('1.9.9'),
        isTrue,
      );
    });

    test('treats a malformed version as zero rather than throwing', () {
      expect(VersionNumber.parse('not-a-version').parts, [0, 0, 0]);
    });
  });

  group('plainReleaseNotes', () {
    test('strips headings, emphasis and code markers', () {
      const markdown = '# 标题\n\n**重点** 和 `代码`\n\n- 第一项\n';
      final plain = plainReleaseNotes(markdown);
      expect(plain, contains('标题'));
      expect(plain, contains('重点'));
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('`')));
      expect(plain, contains('· 第一项'));
    });
  });

  group('ReleaseInfo.preferredApk', () {
    ReleaseAsset asset(String name) =>
        ReleaseAsset(name: name, url: 'https://example.invalid/$name', size: 1);

    test('prefers the universal build', () {
      final release = ReleaseInfo(
        tag: 'v1.0.0',
        name: '',
        notes: '',
        pageUrl: '',
        publishedAt: null,
        assets: [
          asset('goodreader-v1.0.0-arm64-v8a.apk'),
          asset('goodreader-v1.0.0-universal.apk'),
          asset('checksums.txt'),
        ],
      );
      expect(release.preferredApk!.name, contains('universal'));
    });

    test('falls back to arm64 then any apk', () {
      final release = ReleaseInfo(
        tag: 'v1.0.0',
        name: '',
        notes: '',
        pageUrl: '',
        publishedAt: null,
        assets: [asset('app-x86_64.apk'), asset('app-arm64-v8a.apk')],
      );
      expect(release.preferredApk!.name, contains('arm64'));
    });

    test('returns null when no apk is attached', () {
      final release = ReleaseInfo(
        tag: 'v1.0.0',
        name: '',
        notes: '',
        pageUrl: '',
        publishedAt: null,
        assets: [asset('source.tar.gz')],
      );
      expect(release.preferredApk, isNull);
    });
  });
}
