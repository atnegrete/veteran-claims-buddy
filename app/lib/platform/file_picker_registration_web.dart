// The browser picker ships inside file_picker. These are its web pieces.
// ignore: depend_on_referenced_packages
import 'package:file_picker_web/file_picker_web.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// The browser file dialog. Flutter's web plugin list does not always
/// attach this before the first click, so the page attaches it itself.
void registerFilePicker() {
  FilePickerWeb.registerWith(webPluginRegistrar);
}
