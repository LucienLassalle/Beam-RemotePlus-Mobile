/// One command of the "More" sheet, as listed by the mod (answer to
/// `cmd|actions`, see the mod's PROTOCOL.md):
///   - `g:<id>`: a generic command of the game the vehicle is fitted for
///     (4WD, nitrous...), titled by the app;
///   - `v:<name>`: an action the vehicle declares itself, with its [title]
///     in the game language.
class VehicleCommand {
  final String id;

  /// Held like a key (`action_down` / `action_up`) instead of pressed once.
  final bool hold;
  final String? title;

  const VehicleCommand({required this.id, this.hold = false, this.title});

  static const genericPrefix = 'g:';

  /// The generic id ("four_wd"), null for a vehicle's own action.
  String? get genericId => id.startsWith(genericPrefix) ? id.substring(genericPrefix.length) : null;

  static VehicleCommand? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final title = json['title'];
    return VehicleCommand(id: id, hold: json['kind'] == 'hold', title: title is String && title.isNotEmpty ? title : null);
  }
}
