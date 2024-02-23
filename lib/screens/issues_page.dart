import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/custom_shared_preferences.dart';
import '../widgets/issue_card.dart';
import '../models/issue.dart';
import '../services/jira_api_client.dart';

class IssuesPage extends StatefulWidget {
  const IssuesPage({Key? key}) : super(key: key);

  @override
  IssuesPageState createState() => IssuesPageState();
}

class IssuesPageState extends State<IssuesPage> {
  late JiraApiClient _jiraApiClient;
  List<Issue> _issues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeClientAndLoadIssues();
    _saveSettings(); //update last page index
  }

  Future<void> _initializeClientAndLoadIssues() async {
    _jiraApiClient = await JiraApiClient.create();
    await _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> issuesData = await _jiraApiClient.getIssuesAssignedToCurrentUser();
      setState(() {
        _issues = issuesData.map((issueData) => Issue.fromMap(issueData)).toList();
      });
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return; // check ensures widget is still present in the widget tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  _saveSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('lastPageIndex', 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : _issues.isEmpty
              ? const Center(child: Text('No issues found.'))
              : ListView.builder(
                  itemCount: _issues.length,
                  itemBuilder: (context, index) {
                    return IssueCard(issue: _issues[index]);
                  },
                ),
    );
  }
}
