import 'package:dio/dio.dart';

/// Native (io) stub. The Gap Report HTML preview is a web-only convenience —
/// on mobile/desktop you'd typically fetch the PDF instead.
Future<void> platformOpenInBrowser({
  required String url,
  required Dio dio,
  String mimeType = 'text/html; charset=utf-8',
}) async {
  throw UnsupportedError(
    'platformOpenInBrowser is web-only. On native platforms, download the '
    'report as PDF instead.',
  );
}
