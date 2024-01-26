// import 'dart:html' as html;
// import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class CustomSharedPreferences {
  static Future<bool> checkIfLocalStorageIsEnabled() async {
    return true;

    // if (kIsWeb) {
    //   debugPrint("kIsWeb: ${kIsWeb ? "true" : "false"}");
    //   try {
    //     // Try writing to localStorage
    //     html.window.localStorage['testKey'] = 'testValue';
    //     // Try reading from localStorage
    //     bool localStorageIsAvailable =
    //         html.window.localStorage['testKey'] == 'testValue';
    //     // Clean up test entry
    //     html.window.localStorage.remove('testKey');
    //     return localStorageIsAvailable;
    //   } catch (e) {
    //     // Local storage is not available
    //     return false;
    //   }
    // } else {
    //   // For non-web platforms, return true as shared_preferences works without local storage
    //   return true;
    // }
  }

  static Future<SharedPreferences> getInstance() async {
    return SharedPreferences.getInstance();
  }

  // Add other wrapper methods as necessary
}
