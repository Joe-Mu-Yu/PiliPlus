import 'package:dlna_dart/dlna.dart';

/// Treat legacy Lebo control URLs as relative paths, not URI schemes.
///
/// Some Lebo/TCL renderers advertise `controlURL` values that begin with
/// `_urn:schemas-upnp-org:service:`. Joined against the device base URL they
/// look like an unknown URI scheme, so the SOAP request never reaches the
/// device. Prefixing `./` keeps them relative.
void normalizeLegacyDlnaControlUrls(DLNADevice device) {
  for (final service in device.info.serviceList) {
    final path = service['controlURL'];
    if (path is String && path.startsWith('_urn:schemas-upnp-org:service:')) {
      service['controlURL'] = './$path';
    }
  }
}
