/// Release version of the app or of the mod, as stamped at build time from
/// the version given to the build: `0.0.4-0.39` is version 0.0.4 built for
/// BeamNG.drive 0.39 (the suffix is ignored when comparing). A version that
/// is not a release number, or a missing one, is never compared. Same rules
/// as the mod's version.lua.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  final int major;
  final int minor;
  final int patch;

  const ReleaseVersion(this.major, this.minor, this.patch);

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)');

  /// `0.0.4`, `v0.0.4-0.39`; null for null or anything that does not start
  /// with a release number.
  static ReleaseVersion? tryParse(String? text) {
    if (text == null) return null;
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    return ReleaseVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  /// Negative if [a] is older than [b], 0 for the same release, positive if
  /// newer; null when either one is not a release version.
  static int? compareTexts(String? a, String? b) {
    final va = tryParse(a), vb = tryParse(b);
    if (va == null || vb == null) return null;
    return va.compareTo(vb);
  }

  /// [candidate] is a newer release than [current].
  static bool isNewer(String? candidate, String? current) => (compareTexts(candidate, current) ?? 0) > 0;

  @override
  int compareTo(ReleaseVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseVersion && other.major == major && other.minor == minor && other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
