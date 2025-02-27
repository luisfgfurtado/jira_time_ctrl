import 'dart:ui';

import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_shared_preferences.dart';

void storeWindowProperties() async {
  bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
  if (localStorageIsEnabled) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final windowSize = await WindowManager.instance.getSize();
    final windowPosition = await WindowManager.instance.getPosition();

    prefs.setDouble('windowWidth', windowSize.width);
    prefs.setDouble('windowHeight', windowSize.height);
    prefs.setDouble('windowPosX', windowPosition.dx);
    prefs.setDouble('windowPosY', windowPosition.dy);
  } else {
    // Handle the scenario when local storage is not available
    throw Exception("local storage is disabled");
  }
}

Future<Map<String, dynamic>> restoreWindowProperties() async {
  bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
  if (localStorageIsEnabled) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final windowWidth = prefs.getDouble('windowWidth');
    final windowHeight = prefs.getDouble('windowHeight');
    final windowPosX = prefs.getDouble('windowPosX');
    final windowPosY = prefs.getDouble('windowPosY');

    double width = windowWidth ?? 800; // Default width
    double height = windowHeight ?? 600; // Default height
    double posX = windowPosX ?? 100; // Default X position
    double posY = windowPosY ?? 100; // Default Y position

    return {'size': Size(width, height), 'position': Offset(posX, posY)};
  } else {
    // Handle the scenario when local storage is not available
    throw Exception("local storage is disabled");
  }
}
