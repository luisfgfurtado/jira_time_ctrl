import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/issues_page.dart';
import 'screens/settings_page.dart';
import 'screens/timesheet_page.dart';
import 'utils/prefs.dart';
import 'widgets/main_drawer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with WindowListener {
  int _pageIndex = 2;
  late List<Widget> _pages;
  final List<String> _titles = ["Issues assigned to me", "Timesheet", "Settings"];

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

  void setPageIndex(int index) {
    setState(() => _pageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    _pages = [
      const IssuesPage(),
      const TimesheetPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_pageIndex])),
      drawer: MainDrawer(pageIndex: _pageIndex, setPageIndex: setPageIndex),
      body: _pages[_pageIndex],
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
