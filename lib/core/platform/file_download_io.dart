import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Native (iOS / Android / desktop) implementation: downloads to a temp file
/// and opens it with the OS-registered handler.
Future<void> platformDownload({
  required String url,
  required String fileName,
  required Dio dio,
}) async {
  final dir = await getTemporaryDirectory();
  final savePath = '${dir.path}/$fileName';

  await dio.download(url, savePath);

  final result = await OpenFile.open(savePath);
  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}
