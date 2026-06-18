import 'package:uzita/app_localizations.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/neshan_errors.dart';

/// Resolves any caught error to a user-facing localized message when possible.
String userFacingErrorMessage(Object error, AppLocalizations l) {
  if (error is NeshanApiException) {
    return localizeNeshanError(l, error);
  }

  final raw = error.toString().replaceAll('Exception: ', '').trim();
  return raw.isEmpty ? l.error_unknown : raw;
}
