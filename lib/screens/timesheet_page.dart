import 'package:flutter/material.dart';
import 'package:jira_time_ctrl/models/issue_utils.dart';
import 'package:jira_time_ctrl/services/tempo_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/custom_shared_preferences.dart';
import '../widgets/timesheet_table.dart';

class TimesheetPage extends StatefulWidget {
  const TimesheetPage({Key? key}) : super(key: key);

  @override
  TimesheetPageState createState() => TimesheetPageState();
}

class TimesheetPageState extends State<TimesheetPage> {
  late JiraApiClient _jiraApiClient;
  late TempoApiClient _tempoApiClient;
  List<Issue> _issues = [];
  List<Issue> _filteredIssues = [];
  List<ProjectItem> _projects = [];
  bool _isLoading = true;

  int _tempoWorklogsPeriod = 14;
  bool _showAssignedToMe = false;
  bool _showWeekend = false;
  String _timesheetJQL = '';
  String _timesheetAddedIssues = '';
  String _startDate = '';
  String _endDate = '';

  @override
  void initState() {
    super.initState();
    _generalInit();
  }

  _generalInit() async {
    await _loadSettings();
    await _initializeClient();
    await _loadTempoWorklogIssues();
    if (mounted) setState(() => _isLoading = false);
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tempoWorklogsPeriod = prefs.getInt('tempoWorklogsPeriod') ?? 14;
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
    if (!mounted) return;
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
      _showHelpText(e.toString());
      debugPrint(e.toString());
    }
  }

  Future<void> _fullReloadIssues() async {
    if (_startDate == '' || _endDate == '') return;
    setState(() => _isLoading = true); // Set loading to true
    await _loadTempoWorklogIssues();
    await loadIssues(_startDate, _endDate);
    setState(() => _isLoading = false); // Set loading to false
  }

  List<ProjectItem> _createProjectListItems(List<Issue> issues) {
    var uniqueProjectKeys = issues.map((issue) => issue.fields.projectKey).toSet();
    return uniqueProjectKeys.map((projectKey) => ProjectItem(projectKey: projectKey, title: projectKey)).toList();
  }

  Set<String> _getSelectedProjectKeys(List<ProjectItem> projects) {
    // Assuming 'selected' is a property of Project which is true if the project is selected
    return projects.where((project) => project.isChecked).map((project) => project.projectKey).toSet();
  }

  List<Issue> _filterIssuesBySelectedProjects(List<Issue> allIssues, Set<String> selectedProjectKeys) {
    return allIssues.where((issue) => selectedProjectKeys.contains(issue.fields.projectKey)).toList();
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
        _startDate = startDate;
        _endDate = endDate;
        _projects = _createProjectListItems(issues);
        _issues = issues;
        _filteredIssues = _filterIssuesBySelectedProjects(_issues, _getSelectedProjectKeys(_projects));
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      //setState(() => _isLoading = false); // Set loading to false if error occurs
      debugPrint(e.toString());
      _showHelpText(e.toString());
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
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      debugPrint('Error getting issue $issueKey: $e');
      _showHelpText(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: topBar(),
      body: _isLoading
          ? Container(
              color: const Color.fromARGB(255, 116, 116, 116).withOpacity(0.2), // Semi-transparent overlay
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Row(
              children: [
                Flexible(
                  flex: 2, // Convert width to flex value
                  child: Container(
                    width: 180,
                    color: Colors.blueGrey.shade100, // Just for visibility
                    child: Transform.scale(
                      scale: 0.85,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton(
                            onPressed: () {
                              _showHelpText('Not implemented.\nGo to settings and add manually.');
                            },
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.add), // Change color as needed
                                Text('Add Issue'),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _fullReloadIssues();
                            },
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.refresh), // Change color as needed
                                Text('refresh'),
                              ],
                            ),
                          ),
                          _buildActionSwitch(
                            label: 'Show Weekend',
                            value: _showWeekend,
                            onChanged: (value) => setState(() {
                              _showWeekend = value;
                              _saveSettings();
                            }),
                          ),
                          _buildActionSwitch(
                            label: 'Assigned to Me',
                            value: _showAssignedToMe,
                            onChanged: (value) => setState(() {
                              _showAssignedToMe = value;
                              _fullReloadIssues();
                              _saveSettings();
                            }),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text(
                              'Projects', // Title for your list
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _projects.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  leading: Checkbox(
                                    value: _projects[index].isChecked,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _projects[index].isChecked = value ?? false;
                                        _filteredIssues = _filterIssuesBySelectedProjects(_issues, _getSelectedProjectKeys(_projects));
                                      });
                                    },
                                  ),
                                  title: Text(_projects[index].title),
                                  onTap: () {
                                    // Change the checkbox value on tapping the whole ListTile
                                    setState(() {
                                      _projects[index].isChecked = !_projects[index].isChecked;
                                      _filteredIssues = _filterIssuesBySelectedProjects(_issues, _getSelectedProjectKeys(_projects));
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content (TimesheetTable)
                Expanded(
                  flex: 10,
                  child: TimesheetTable(
                    issues: _issues,
                    filteredIssues: _filteredIssues,
                    showWeekend: _showWeekend,
                    jiraApiClient: _jiraApiClient,
                    loadIssues: loadIssues, // Your existing callback
                    onUpdateIssue: updateIssue, // Your existing callback
                    tempoWorklogsPeriod: _tempoWorklogsPeriod, //Tempo Worklog Period (last n of days)
                  ),
                ),
              ],
            ),
    );
  }
}

class ProjectItem {
  String projectKey;
  String title;
  bool isChecked;

  ProjectItem({required this.projectKey, required this.title, this.isChecked = true});
}
