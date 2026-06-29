/// Client-side Neshan error codes used with [NeshanApiException.neshanStatus].
abstract final class NeshanErrorCodes {
  static const addressEmpty = 'AddressEmpty';
  static const geocodingNotFound = 'GeocodingNotFound';
  static const invalidGeocodingLocation = 'InvalidGeocodingLocation';
  static const invalidGeocodingCoordinates = 'InvalidGeocodingCoordinates';
  static const geocodingRequestFailed = 'GeocodingRequestFailed';
  static const routingNotFound = 'RoutingNotFound';
  static const invalidRoutingResponse = 'InvalidRoutingResponse';
  static const routingNoLegs = 'RoutingNoLegs';
  static const routingNoValidLegs = 'RoutingNoValidLegs';
  static const routingRequestFailed = 'RoutingRequestFailed';
  static const sdkEmptyResponse = 'SdkEmptyResponse';
  static const sdkInvalidCoordinates = 'SdkInvalidCoordinates';
  static const backendProxyFailed = 'BackendProxyFailed';
  static const backendUnauthorized = 'BackendUnauthorized';
  static const invalidArgument = 'INVALID_ARGUMENT';
  static const coordinateParseError = 'CoordinateParseError';
}
