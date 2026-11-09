/// Browser device-orientation (used only on the web build, e.g. iPhone Safari,
/// where there is no magnetometer API). On mobile builds the stub is used.
export 'web_orientation_stub.dart' if (dart.library.js_interop) 'web_orientation_web.dart';
