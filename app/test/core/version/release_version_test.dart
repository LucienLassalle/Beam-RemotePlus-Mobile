import 'package:beam_remoteplus/core/version/release_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tryParse', () {
    test('reads the release numbers, with or without v and suffix', () {
      expect(ReleaseVersion.tryParse('0.0.4'), const ReleaseVersion(0, 0, 4));
      expect(ReleaseVersion.tryParse('v0.0.4-0.39'), const ReleaseVersion(0, 0, 4));
      expect(ReleaseVersion.tryParse('0.0.4-delta'), const ReleaseVersion(0, 0, 4));
      expect(ReleaseVersion.tryParse('1.12.3-0.39'), const ReleaseVersion(1, 12, 3));
    });

    test('rejects what is not a release number', () {
      expect(ReleaseVersion.tryParse('PoC'), isNull);
      expect(ReleaseVersion.tryParse(''), isNull);
      expect(ReleaseVersion.tryParse(null), isNull);
    });
  });

  group('compareTexts', () {
    test('orders releases number by number', () {
      expect(ReleaseVersion.compareTexts('0.0.3', '0.0.4'), lessThan(0));
      expect(ReleaseVersion.compareTexts('0.1.0', '0.0.9'), greaterThan(0));
      expect(ReleaseVersion.compareTexts('0.0.10', '0.0.9'), greaterThan(0));
      expect(ReleaseVersion.compareTexts('1.0.0', '0.99.99'), greaterThan(0));
    });

    test('ignores the suffix', () {
      expect(ReleaseVersion.compareTexts('0.0.4-0.39', '0.0.4'), 0);
      expect(ReleaseVersion.compareTexts('v0.0.4-0.39', '0.0.4-0.40'), 0);
    });

    test('cannot compare an unknown version', () {
      expect(ReleaseVersion.compareTexts('PoC', '0.0.4'), isNull);
      expect(ReleaseVersion.compareTexts('0.0.4', null), isNull);
    });
  });

  test('isNewer is false whenever the versions cannot be compared', () {
    expect(ReleaseVersion.isNewer('v0.0.5-0.39', '0.0.4'), isTrue);
    expect(ReleaseVersion.isNewer('0.0.4', '0.0.4-0.39'), isFalse);
    expect(ReleaseVersion.isNewer('0.0.5', null), isFalse);
  });
}
