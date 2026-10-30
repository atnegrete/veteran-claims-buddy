import 'package:flutter/widgets.dart';

/// Width where the shell moves navigation into the drawer.
const shellDrawerWidth = 600.0;

/// A phone in either orientation.
///
/// Uses the short edge so a landscape phone still gets the dense page, and a
/// desktop window does not.
bool isPhoneLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < shellDrawerWidth;
}
