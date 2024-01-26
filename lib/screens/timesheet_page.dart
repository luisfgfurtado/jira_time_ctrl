import 'package:flutter/material.dart';
import 'package:jira_time_ctrl/models/issue_utils.dart';
import 'package:jira_time_ctrl/services/tempo_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/custom_shared_preferences.dart';
import '../widgets/timesheet_table.dart';

class TimesheetPage extends StatefulWidget {
  const TimesheetPage({super.key});

  @override
  _TimesheetPageState createState() => _TimesheetPageState();
}

class _TimesheetPageState extends State<TimesheetPage> {
  late JiraApiClient _jiraApiClient;
  late TempoApiClient _tempoApiClient;
  List<Issue> _issues = [];
  bool _isLoading = true;

  bool _showAssignedToMe = false;
  bool _showWeekend = false;
  String _timesheetJQL = '';
  String _timesheetAddedIssues = '';

  @override
  void initState() {
    super.initState();
    _generalInit();
  }

  _generalInit() async {
    await _loadSettings();
    await _initializeClient();
    await _loadTempoWorklogIssues();
    setState(() => _isLoading = false);
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showAssignedToMe = prefs.getBool('showAssignedToMe') ?? false;
      _showWeekend = prefs.getBool('showWeekend') ?? false;
      _timesheetAddedIssues = prefs.getString('jiraTimesheetAddedIssues') ?? '';
      _timesheetJQL = prefs.getString('jiraTimesheetJQL') ?? '(worklogDate >= #STARTDATE# AND worklogDate <= #ENDDATE# AND worklogAuthor = currentuser())';
    });
    _saveSettings(); //update last page index
  }

  Future<void> _initializeClient() async {
    _jiraApiClient = await JiraApiClient.create();
    _tempoApiClient = await TempoApiClient.create();
  }

  Widget _buildActionSwitch({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(scale: 0.7, child: Switch(value: value, onChanged: onChanged)),
        Text(label),
      ],
    );
  }

  _saveSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('showAssignedToMe', _showAssignedToMe);
      prefs.setBool('showWeekend', _showWeekend);
      prefs.setInt('lastPageIndex', 1);
    } else {
      // Handle the scenario when local storage is not available
      _showHelpText("local storage is disabled");
    }
  }

  void _showHelpText(String helpText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: Text('Field Information'),
          content: Text(helpText),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadTempoWorklogIssues() async {
    //setState(() => _isLoading = true); // Set loading to true
    try {
      List<Issue> issues = await _tempoApiClient.getTempoWorklogsIssues();
      setState(() {
        _issues = issues;
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      //setState(() => _isLoading = false); // Set loading to false if error occurs
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> loadIssues(String startDate, String endDate) async {
    String jql = _timesheetJQL.replaceAll('#STARTDATE#', startDate).replaceAll('#ENDDATE#', endDate);
    if (_showAssignedToMe) {
      jql += ' OR (assignee=currentuser() AND status NOT IN (Done,Closed,resolved,Cancelled))';
    }
    if (_timesheetAddedIssues.isNotEmpty) {
      jql += ' OR (issuekey IN ($_timesheetAddedIssues))';
    }
    //setState(() => _isLoading = true); // Set loading to true
    try {
      List<dynamic> issuesData = await _jiraApiClient.getIssues(jql);
      List<Issue> issues = issuesData.map((issueData) => Issue.fromMap(issueData)).toList();
      issues = mergeIssueLists(issues, _issues);
      issues.sort((a, b) {
        int projectIdComparison = a.fields.projectKey.compareTo(b.fields.projectKey);
        if (projectIdComparison != 0) {
          return projectIdComparison;
        } else {
          return a.key.compareTo(b.key);
        }
      });
      setState(() {
        _issues = issues;
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      //setState(() => _isLoading = false); // Set loading to false if error occurs
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> updateIssue(String issueKey) async {
    try {
      dynamic updatedIssueData = await _jiraApiClient.getIssue(issueKey);
      //debugPrint('returned\n$updatedIssueData');
      Issue updatedIssue = Issue.fromMap(updatedIssueData);

      setState(() {
        int index = _issues.indexWhere((issue) => issue.key == updatedIssue.key);
        if (index != -1) {
          _issues[index] = updatedIssue;
        }
        _isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      debugPrint('Error getting issue $issueKey: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented.\nGo to configuration and add manually.')),
              );
            },
            child: const Row(
              children: <Widget>[
                Icon(Icons.add), // Change color as needed
                Text('Add Issue'),
              ],
            ),
          ),
          _buildActionSwitch(
            label: 'Assigned to Me',
            value: _showAssignedToMe,
            onChanged: (value) => setState(() {
              _showAssignedToMe = value;
              _saveSettings();
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildActionSwitch(
              label: 'Show Weekend',
              value: _showWeekend,
              onChanged: (value) => setState(() {
                _showWeekend = value;
                _saveSettings();
              }),
            ),
          ),
        ],
      ),
      body: (_isLoading)
          ? Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          : TimesheetTable(
              issues: _issues,
              showWeekend: _showWeekend,
              jiraApiClient: _jiraApiClient,
              loadIssues: loadIssues, // Your existing callback
              onUpdateIssue: updateIssue, // Your existing callback
            ),
    );
  }
}
