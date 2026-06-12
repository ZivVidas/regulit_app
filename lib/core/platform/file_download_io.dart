import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Native (iOS / Android / desktop) implementation: downloads to a temp file
/// and opens it with the OS-registered handler.
///
/// `receiveTimeout` / `sendTimeout` default to 5 minutes so long server
/// jobs (Gap Report PDF — 3 LLM calls + Chromium render = up to ~90 s
/// on cold paths) don't fail with a generic connection-timeout error.
Future<void> platformDownload({
  required String url,
  required String fileName,
  required Dio dio,
  Duration receiveTimeout = const Duration(minutes: 5),
  Duration sendTimeout = const Duration(minutes: 5),
}) async {
  final dir = await getTemporaryDirectory();
  final savePath = '${dir.path}/$fileName';

  // connectTimeout lives on BaseOptions, not per-request Options.
  // Swap it for the call and restore afterwards so other dio users
  // aren't surprised.
  final originalConnect = dio.options.connectTimeout;
  dio.options.connectTimeout = const Duration(minutes: 5);
  try {
    await dio.download(
      url,
      savePath,
      options: Options(
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      ),
    );
  } finally {
    dio.options.connectTimeout = originalConnect;
  }

  final result = await OpenFile.open(savePath);
  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}
