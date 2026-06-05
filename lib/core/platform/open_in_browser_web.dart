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
  /// Wrapped in try/catch because dart:html returns a "null window" stub
  /// when the popup is blocked, and merely *touching* it throws — but
  /// once we're in a real gesture this should succeed.
  void openInGesture() {
    try {
      html.window.open(blobUrl, '_blank');
    } catch (_) {
      // Best-effort — if the browser still blocks here there is nothing
      // we can do programmatically.
    }
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

  // Try the automatic open. dart:html's Window.open returns a stub object
  // when the popup is blocked; that stub throws "Attempting to use a null
  // window opened in Window.open" on any property access. We use that as
  // our block-detection probe: touch `.closed` inside a try/catch.
  //
  // We do NOT revoke the blob URL — the new tab needs it to load.
  try {
    final win = html.window.open(blobUrl, '_blank');
    final isClosed = win.closed; // throws if stub (= blocked)
    if (isClosed == true) {
      return DeferredOpen(blobUrl); // opened then immediately closed
    }
    return null; // success
  } catch (_) {
    return DeferredOpen(blobUrl); // blocked
  }
}
