import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/configurations_page.dart';
import 'screens/issues_page.dart';
import 'screens/timesheet_page.dart';
import 'utils/prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowManager.instance.ensureInitialized();

  final windowProperties = await restoreWindowProperties();
  WindowManager.instance.setSize(windowProperties['size']);
  WindowManager.instance.setPosition(windowProperties['position']);

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  int _pageIndex = 1;
  final List<Widget> _pages = [
    const IssuesPage(),
    const TimesheetPage(),
    const ConfigurationsPage(),
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_pageIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageIndex,
        onTap: (index) {
          setState(() {
            _pageIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Timesheet'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configurations'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
