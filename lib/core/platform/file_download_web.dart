// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Web implementation: fetches bytes authenticated via [dio] and triggers
/// the browser's native save-as dialog. No `path_provider` involved.
Future<void> platformDownload({
  required String url,
  required String fileName,
  required Dio dio,
}) async {
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data ?? [];
  final blob = html.Blob([bytes]);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: blobUrl)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(blobUrl);
}
