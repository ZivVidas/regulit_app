// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Web implementation: fetches HTML bytes authenticated via [dio] (the
/// existing JWT interceptor attaches the Authorization header), wraps the
/// bytes in a Blob, and opens that blob in a new browser tab.
///
/// Why a blob instead of `window.open(url)` directly?
///   The endpoint requires auth. `window.open` on a URL string doesn't
///   send custom headers (the request comes from the new tab, not Dio).
///   Fetching first with Dio + opening the bytes solves that.
Future<void> platformOpenInBrowser({
  required String url,
  required Dio dio,
  String mimeType = 'text/html; charset=utf-8',
}) async {
  final response = await dio.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      // Long enough to cover the LLM calls behind the preview endpoint.
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
  final bytes = response.data ?? <int>[];
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(blobUrl, '_blank');
  // We intentionally don't revoke the blob URL immediately — the new tab
  // needs it to load. The browser reclaims it when the tab navigates away.
}
