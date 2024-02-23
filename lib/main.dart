import 'package:flutter/material.dart';
import 'package:jira_time_ctrl/widgets/main_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/settings_page.dart';
import 'screens/issues_page.dart';
import 'screens/timesheet_page.dart';
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
      home: const _MyHomePage(),
    );
  }
}

class _MyHomePage extends StatefulWidget {
  const _MyHomePage();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<_MyHomePage> with WindowListener {
  int _pageIndex = 1;
  late List<Widget> _pages;
  final List<String> _titles = ["Issues assigned to me", "Timesheet", "Settings"];

  @override
  void initState() {
    super.initState();

    _pages = [
      const IssuesPage(),
      const TimesheetPage(),
      const SettingsPage(),
    ];

    windowManager.addListener(this);
    _loadSettings();
  }

  @override
  void onWindowResize() {
    super.onWindowResize();
    storeWindowProperties();
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pageIndex = prefs.getInt('lastPageIndex') ?? 1;
    });
  }

  void _setPageIndex(int index) {
    setState(() => _pageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_pageIndex])),
      drawer: MainDrawer(pageIndex: _pageIndex, setPageIndex: _setPageIndex),
      body: _pages[_pageIndex],
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
