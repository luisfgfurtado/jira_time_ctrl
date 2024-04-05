import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'my_home_page.dart';
import 'utils/prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowManager.instance.ensureInitialized();

  final windowProperties = await restoreWindowProperties();
  windowManager.setTitle('Jira Time Control');
  WindowManager.instance.setSize(windowProperties['size']);
  //WindowManager.instance.setPosition(windowProperties['position']);
  WindowManager.instance.center();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jira Time Entries',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        // Define the default text theme
        textTheme: const TextTheme(
          titleMedium: TextStyle(fontSize: 14, color: Colors.blue), // Default style for TextFormField
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true, // this will remove the default content padding
          //contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          // Apply the style to the label, hint, and helper text
          labelStyle: TextStyle(fontSize: 14),
          hintStyle: TextStyle(fontSize: 14),
          helperStyle: TextStyle(fontSize: 14),
          // Apply the style to the text field's content
          contentPadding: EdgeInsets.all(10),
          border: OutlineInputBorder(),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}
