/// Platform-agnostic "fetch authenticated HTML and open it in a new
/// browser tab" helper.
///
/// On web  → fetches bytes via Dio (so the auth interceptor adds the
///           Bearer token), creates a Blob, opens it in a new tab.
/// On native → currently unsupported; throws.
library;

export 'open_in_browser_io.dart' if (dart.library.html) 'open_in_browser_web.dart';
