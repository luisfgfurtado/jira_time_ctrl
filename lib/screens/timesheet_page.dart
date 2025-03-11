import 'package:flutter/material.dart';
import 'package:jira_time_ctrl/models/issue_utils.dart';
import 'package:jira_time_ctrl/models/my_timesheet_info.dart';
import 'package:jira_time_ctrl/services/tempo_api_client.dart';
import 'package:jira_time_ctrl/services/timesheet_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/custom_shared_preferences.dart';
import '../widgets/action_switch.dart';
import '../widgets/timesheet_table.dart';

class TimesheetPage extends StatefulWidget {
  const TimesheetPage({super.key});
  //const TimesheetPage({Key? key}) : super(key: key);

  @override
  TimesheetPageState createState() => TimesheetPageState();
}

class TimesheetPageState extends State<TimesheetPage> {
  late JiraApiClient _jiraApiClient;
  late TempoApiClient _tempoApiClient;
  late TimesheetApiClient _timesheetApiClient;
  late MyTimesheetInfo _myTimesheetInfo;
  List<Issue> _issues = [];
  List<Issue> _filteredIssues = [];
  List<ProjectItem> _projects = [];
  bool _isLoading = true;

  String _jiraApiUserKey = '';
  int _tempoWorklogsPeriod = 14;
  bool _showAssignedToMe = false;
  bool _showWithWorklog = true;
  bool _showWeekend = false;
  String _timesheetJQL = '';
  String _timesheetAddedIssues = '';
  List<String> _timesheetAddedIssuesList = [];
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
      _jiraApiUserKey = prefs.getString('jiraApiUserKey') ?? _jiraApiUserKey;
      _tempoWorklogsPeriod = prefs.getInt('tempoWorklogsPeriod') ?? 14;
      _showAssignedToMe = prefs.getBool('showAssignedToMe') ?? false;
      _showWithWorklog = prefs.getBool('showWithWorklog') ?? true;
      _showWeekend = prefs.getBool('showWeekend') ?? false;
      _timesheetAddedIssues = prefs.getString('jiraTimesheetAddedIssues') ?? '';
      _timesheetJQL = prefs.getString('jiraTimesheetJQL') ?? '(worklogDate >= #STARTDATE# AND worklogDate <= #ENDDATE# AND worklogAuthor = currentuser())';
      _timesheetAddedIssuesList = _timesheetAddedIssues.split(',');
    });
    _saveSettings(); //update last page index
  }

  Future<void> _initializeClient() async {
    _jiraApiClient = await JiraApiClient.create();
    _tempoApiClient = await TempoApiClient.create();
    _timesheetApiClient = await TimesheetApiClient.create();
    _myTimesheetInfo = MyTimesheetInfo(
      startDate: null,
      endDate: null,
      maxHoursPerDay: 24,
      addedIssues: [],
      customAttributes: [],
      customAttributeValues: [],
    );
  }

  _saveSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      _timesheetAddedIssues = _timesheetAddedIssuesList.join(',');
      prefs.setString('jiraTimesheetAddedIssues', _timesheetAddedIssues);
      prefs.setBool('showAssignedToMe', _showAssignedToMe);
      prefs.setBool('showWithWorklog', _showWithWorklog);
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
    try {
      List<Issue> issues = await _tempoApiClient.getTempoWorklogsIssues();
      setState(() {
        _issues = issues;
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      //setState(() => _isLoading = false); // Set loading to false if error occurs
      if (!e.toString().contains("401") && !e.toString().contains("400")) {
        _showHelpText(e.toString());
      }
      //debugPrint(e.toString());
    }
  }

  Future<void> _loadMyTimeSheetInfo(String startDate, String endDate) async {
    try {
      MyTimesheetInfo myTimesheetInfo = await _timesheetApiClient.getMyTimesheetInfo(startDate, endDate);
      setState(() {
        _myTimesheetInfo = myTimesheetInfo;
      });
    } catch (e) {
      if (!e.toString().contains("401") && !e.toString().contains("400")) {
        _showHelpText(e.toString());
      }
    }
  }

  Future<void> _fullReloadIssues() async {
    debugPrint("fullReloadIssues");
    if (_startDate == '' || _endDate == '') return;
    setState(() => _isLoading = true); // Set loading to true
    await _loadMyTimeSheetInfo(_startDate, _endDate);
    await _loadTempoWorklogIssues();
    await loadIssues(_startDate, _endDate);

    // Verifica se existem customAttributeValues e se a lista tem elementos
    if (_myTimesheetInfo.customAttributeValues.isNotEmpty) {
      addIssuesCustomAttributeValues(_issues, _myTimesheetInfo.customAttributeValues);
    }

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

  List<Issue> _applyFilters(List<Issue> allIssues) {
    List<Issue> fIssues = _filterIssuesBySelectedProjects(_issues, _getSelectedProjectKeys(_projects));
    return fIssues.where((issue) {
      return (_showAssignedToMe && issue.fields.assignee.me) ||
          (_showWithWorklog && issue.fields.worklog.worklogs.isNotEmpty) ||
          (_timesheetAddedIssuesList.contains(issue.key));
    }).toList();
  }

  Future<void> loadIssues(String startDate, String endDate) async {
    String jql = _timesheetJQL.trim();
    if (_showWithWorklog) {
      jql += '${jql.isNotEmpty ? ' OR ' : ''}(worklogDate >= #STARTDATE# AND worklogDate <= #ENDDATE# AND worklogAuthor = currentuser())';
    }
    if (_showAssignedToMe) {
      jql += '${jql.isNotEmpty ? ' OR ' : ''}(assignee=currentuser() AND status NOT IN (Done,Closed,resolved,Cancelled))';
    }
    if (_timesheetAddedIssues.isNotEmpty) {
      jql += '${jql.isNotEmpty ? ' OR ' : ''}(issuekey IN ($_timesheetAddedIssues))';
    }
    jql = jql.replaceAll('#STARTDATE#', startDate).replaceAll('#ENDDATE#', endDate);
    try {
      List<dynamic> issuesData = await _jiraApiClient.getIssues(jql);
      List<Issue> issues = issuesData.map((issueData) => Issue.fromMap(issueData, _jiraApiUserKey)).toList();
      issues = mergeIssueLists(issues, _issues);
      issues.sort((a, b) {
        int projectIdComparison = a.fields.projectKey.compareTo(b.fields.projectKey);
        if (projectIdComparison != 0) {
          return projectIdComparison;
        } else {
          return a.key.compareTo(b.key);
        }
      });

      //load custom attributes
      await _loadMyTimeSheetInfo(startDate, endDate);
      // Verifica se existem customAttributeValues e se a lista tem elementos
      if (_myTimesheetInfo.customAttributeValues.isNotEmpty) {
        addIssuesCustomAttributeValues(_issues, _myTimesheetInfo.customAttributeValues);
      }

      setState(() {
        _startDate = startDate;
        _endDate = endDate;
        _projects = _createProjectListItems(issues);
        _issues = issues;
        _filteredIssues = _applyFilters(_issues);
        //_isLoading = false; // Set loading to false after data is loaded
      });
    } catch (e) {
      //setState(() => _isLoading = false); // Set loading to false if error occurs
      if (e.toString().contains("401") || e.toString().contains("400")) {
        _showHelpText("Authentication error.\nCheck the settings to make sure your Jira API key is configured correctly.");
      } else {
        _showHelpText(e.toString());
      }
      //debugPrint(e.toString());
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
                Container(
                  width: 220,
                  padding: EdgeInsets.zero,
                  color: Colors.blueGrey.shade100, // Just for visibility
                  child: Transform.scale(
                    scale: 0.85,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        ActionSwitch(
                            label: 'Show Weekend',
                            value: _showWeekend,
                            onChanged: (value) => setState(() {
                                  _showWeekend = value;
                                  _saveSettings();
                                })),
                        ActionSwitch(
                            label: 'Assigned to Me',
                            value: _showAssignedToMe,
                            onChanged: (value) => setState(() {
                                  _showAssignedToMe = value;
                                  _saveSettings();
                                  _fullReloadIssues();
                                })),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: ActionSwitch(
                                  label: 'With worklog',
                                  value: _showWithWorklog,
                                  onChanged: (value) => setState(() {
                                        _showWithWorklog = value;
                                        _saveSettings();
                                        _fullReloadIssues();
                                      })),
                            ),
                            IconButton(
                              iconSize: 16,
                              icon: const Icon(Icons.help_outline),
                              onPressed: () => _showHelpText('Use Tempo API to retrieve last \'n\' days issues with worklogs registered.'),
                            ),
                          ],
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
                                visualDensity: const VisualDensity(vertical: -4.0),
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
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () async {
                            final textController = TextEditingController();

                            final enteredIssueKey = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Add Issue'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter Issue Key',
                                  ),
                                  controller: textController,
                                  onSubmitted: (value) => Navigator.pop(context, value), // Submit on ENTER
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, textController.text),
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            );

                            if (enteredIssueKey != null && enteredIssueKey.isNotEmpty && !_timesheetAddedIssuesList.contains(enteredIssueKey)) {
                              setState(() {
                                _timesheetAddedIssuesList.add(enteredIssueKey);
                                _saveSettings();
                                _fullReloadIssues();
                              });
                            }
                          },
                          child: const Row(
                            children: <Widget>[
                              Icon(Icons.add), // Change color as needed
                              Text('Add Issue'),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8.0, // Adjust spacing between chips as needed
                          runSpacing: 4.0, // Adjust spacing between chip rows as needed
                          children: List.generate(_timesheetAddedIssuesList.length, (index) {
                            final issueKey = _timesheetAddedIssuesList[index];
                            return Chip(
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              onDeleted: () => setState(() {
                                _timesheetAddedIssuesList.removeAt(index);
                                _saveSettings();
                                _fullReloadIssues();
                              }),
                              deleteButtonTooltipMessage: "remove issue $issueKey",
                              deleteIconColor: Theme.of(context).primaryColorLight,
                              label: Text(issueKey, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).primaryColorLight)),
                              backgroundColor: Theme.of(context).primaryColorDark,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main content (TimesheetTable)
                Expanded(
                  child: TimesheetTable(
                    issues: _issues,
                    filteredIssues: _filteredIssues,
                    showWeekend: _showWeekend,
                    jiraApiClient: _jiraApiClient,
                    myTimesheetInfo: _myTimesheetInfo,
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
