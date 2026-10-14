// Resolve an application's bundle ID using Launch Services, without launching it.
ObjC.import('AppKit');
function run(argv) {
  var mode = argv[0];
  var value = argv[1];
  var app;
  if (mode === 'app') {
    var path = $.NSWorkspace.sharedWorkspace.fullPathForApplication(value);
    if (path.isNil()) return '';
    app = $.NSURL.fileURLWithPath(path);
  } else {
    var url = mode === 'url' ? $.NSURL.URLWithString(value) : $.NSURL.fileURLWithPath(value);
    app = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL(url);
  }
  if (app.isNil()) return '';
  return ObjC.unwrap($.NSBundle.bundleWithURL(app).bundleIdentifier);
}
