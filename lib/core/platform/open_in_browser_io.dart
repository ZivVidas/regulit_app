import 'package:dio/dio.dart';

/// Returned by [platformOpenInBrowser] on web when the popup was blocked.
/// On native this type still exists (so callers can reference it) but is
/// never returned — the function throws instead.
class DeferredOpen {
  final String blobUrl;
  DeferredOpen(this.blobUrl);

  void openInGesture() {
    throw UnsupportedError('DeferredOpen is web-only.');
  }
}

/// Native (io) stub. The Gap Report HTML preview is a web-only convenience —
/// on mobile/desktop you'd typically fetch the PDF instead.
Future<DeferredOpen?> platformOpenInBrowser({
  required String url,
  required Dio dio,
  String mimeType = 'text/html; charset=utf-8',
}) async {
  throw UnsupportedError(
    'platformOpenInBrowser is web-only. On native platforms, download the '
    'report as PDF instead.',
  );
}
