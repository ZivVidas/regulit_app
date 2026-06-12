// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Web implementation: fetches bytes authenticated via [dio] and triggers
/// the browser's native save-as dialog. No `path_provider` involved.
///
/// `connectTimeout` / `receiveTimeout` are deliberately long because some
/// downloads — like the Gap Report PDF endpoint — block on server-side
/// work (3 LLM calls + headless Chromium render) that easily exceeds
/// Dio's 30-second defaults. Caller can override by passing a smaller
/// value when downloading a static file.
Future<void> platformDownload({
  required String url,
  required String fileName,
  required Dio dio,
  Duration receiveTimeout = const Duration(minutes: 5),
  Duration sendTimeout = const Duration(minutes: 5),
}) async {
  // NOTE: per-request options can't override `connectTimeout` in Dio —
  // it's a base-options-only field. We work around this by reading the
  // dio's base options, swapping in a long connectTimeout, and using
  // a fresh Options on the call. If the user's underlying connection
  // ever times out *after* the data starts flowing, receiveTimeout
  // takes over.
  final originalConnect = dio.options.connectTimeout;
  dio.options.connectTimeout = const Duration(minutes: 5);
  late final Response<List<int>> response;
  try {
    response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      ),
    );
  } finally {
    dio.options.connectTimeout = originalConnect;
  }
  final bytes = response.data ?? [];
  final blob = html.Blob([bytes]);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: blobUrl)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(blobUrl);
}
