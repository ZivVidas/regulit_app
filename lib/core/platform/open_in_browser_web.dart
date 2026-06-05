// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Returned by [platformOpenInBrowser] when the browser **blocked** the
/// automatic popup (production domains do this; localhost doesn't, which
/// is why dev "just works" and prod silently fails).
///
/// The caller should surface a button whose `onPressed` calls
/// [openInGesture] — because that click is a fresh user gesture, the
/// browser will allow `window.open` from inside it.
class DeferredOpen {
  final String blobUrl;
  DeferredOpen(this.blobUrl);

  /// MUST be invoked synchronously from a user gesture (click handler).
  void openInGesture() {
    html.window.open(blobUrl, '_blank');
  }
}

/// Web implementation: fetches HTML bytes authenticated via [dio] (the
/// existing JWT interceptor attaches the Authorization header), wraps the
/// bytes in a Blob, and tries to open that blob in a new browser tab.
///
/// Returns:
///   * `null` — the popup opened automatically; caller is done.
///   * a [DeferredOpen] — the popup was blocked (Chrome's default on prod
///     domains when `window.open` is called after an `await`). Caller MUST
///     show a button whose onPressed invokes `result.openInGesture()`.
///
/// Why a blob instead of `window.open(url)` directly?
///   The endpoint requires auth. `window.open` on a URL string doesn't
///   send custom headers (the request comes from the new tab, not Dio).
///   Fetching first with Dio + opening the bytes solves that.
Future<DeferredOpen?> platformOpenInBrowser({
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

  // Try the automatic open. Browsers return null when they block.
  final win = html.window.open(blobUrl, '_blank');

  // Heuristic for "blocked": the returned window is null, OR it's closed
  // immediately, OR it has no top/document accessor. Some blockers return
  // a window-like stub. The most reliable signal is `null` though.
  // We don't revoke the blob URL — the new tab needs it.
  if (win.closed ?? true) {
    return DeferredOpen(blobUrl);
  }
  return null;
}
