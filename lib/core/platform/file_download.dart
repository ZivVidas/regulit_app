/// Platform-agnostic file download helper.
///
/// On web  → fetches bytes via Dio and triggers a browser save-as dialog.
/// On native → downloads to the OS temp directory and opens with the OS handler.
///
/// Usage:
///   await platformDownload(url: '/files/123/download', fileName: 'report.pdf', dio: dio);
///   // throws on network or open-file error.
library;

export 'file_download_io.dart' if (dart.library.html) 'file_download_web.dart';
