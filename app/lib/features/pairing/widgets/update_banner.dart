import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/platform/links.dart';
import '../../../core/version/update_scope.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Says that a newer app was released, with a link to its release page.
/// Nothing when the app is up to date or the releases are unknown.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final release = UpdateScope.maybeOf(context)?.appUpdate;
    if (release == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.orangeAccent.withValues(alpha: 0.15),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.system_update, color: Colors.orangeAccent),
        title: Text(l10n.updateAppAvailable(release.version)),
        trailing: TextButton(
          onPressed: () => unawaited(openExternalLink(context, release.url)),
          child: Text(l10n.updateDownload),
        ),
      ),
    );
  }
}
