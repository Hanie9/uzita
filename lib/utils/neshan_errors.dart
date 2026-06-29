import 'package:uzita/app_localizations.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/neshan_error_codes.dart';

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
    case NeshanErrorCodes.backendUnauthorized:
      return l.driver_neshan_error_backend_unauthorized;
    case NeshanErrorCodes.backendProxyFailed:
      return l.driver_neshan_error_backend_failed;
    case 'KeyNotFound':
      return l.driver_neshan_error_key_not_found;
    case 'LimitExceeded':
      return l.driver_neshan_error_limit;
    case 'RateExceeded':
      return l.driver_neshan_error_rate;
    case NeshanErrorCodes.addressEmpty:
      return l.driver_neshan_error_address_empty;
    case NeshanErrorCodes.geocodingNotFound:
      return l.driver_neshan_error_geocoding_not_found;
    case NeshanErrorCodes.invalidGeocodingLocation:
    case NeshanErrorCodes.invalidGeocodingCoordinates:
    case NeshanErrorCodes.sdkInvalidCoordinates:
      return l.driver_neshan_error_geocoding_invalid;
    case NeshanErrorCodes.geocodingRequestFailed:
      return l.driver_neshan_error_geocoding_failed;
    case NeshanErrorCodes.routingNotFound:
      return l.driver_neshan_error_routing_not_found;
    case NeshanErrorCodes.invalidRoutingResponse:
      return l.driver_neshan_error_routing_invalid;
    case NeshanErrorCodes.routingNoLegs:
    case NeshanErrorCodes.routingNoValidLegs:
      return l.driver_neshan_error_routing_no_legs;
    case NeshanErrorCodes.routingRequestFailed:
      return l.driver_neshan_error_routing_failed;
    case NeshanErrorCodes.sdkEmptyResponse:
      return l.driver_neshan_error_sdk_response;
    case NeshanErrorCodes.invalidArgument:
    case NeshanErrorCodes.coordinateParseError:
      return l.driver_neshan_error_invalid_argument;
    default:
      return l.driver_route_error;
  }
}

bool isServiceTypeNeshanKey(String key) =>
    key.trim().toLowerCase().startsWith('service.');

bool isWebTypeNeshanKey(String key) =>
    key.trim().toLowerCase().startsWith('web.');
