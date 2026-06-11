import 'package:uzita/app_localizations.dart';
import 'package:uzita/services/neshan_service.dart';

/// Maps Neshan API error statuses to user-facing localized messages.
String localizeNeshanError(AppLocalizations l, NeshanApiException error) {
  switch (error.neshanStatus) {
    case 'ApiServiceListError':
      return l.driver_neshan_error_service_list;
    case 'ApiKeyTypeError':
      return l.driver_neshan_error_key_type;
    case 'ApiWhiteListError':
      return l.driver_neshan_error_whitelist;
    case 'BackendProxyNotFound':
    case 'BackendKeyMissing':
      return l.driver_neshan_error_backend_proxy;
    case 'KeyNotFound':
      return l.driver_neshan_error_key_not_found;
    case 'LimitExceeded':
      return l.driver_neshan_error_limit;
    case 'RateExceeded':
      return l.driver_neshan_error_rate;
    default:
      if (error.message.isNotEmpty) return error.message;
      return l.driver_route_error;
  }
}

bool isServiceTypeNeshanKey(String key) =>
    key.trim().toLowerCase().startsWith('service.');

bool isWebTypeNeshanKey(String key) =>
    key.trim().toLowerCase().startsWith('web.');
