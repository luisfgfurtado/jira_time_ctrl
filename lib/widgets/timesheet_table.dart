import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jira_time_ctrl/models/issue_utils.dart';
import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/dateformat.dart';
import '../utils/issue_utilities.dart';
import 'worklog_detail_dialog.dart';

class TimesheetTable extends StatefulWidget {
  final Future<void> Function(String, String) loadIssues; // Load issues
  final Future<void> Function(String) onUpdateIssue; // Add this
  final List<Issue> issues;
  final bool showWeekend;
  final JiraApiClient jiraApiClient;

  const TimesheetTable({
    Key? key,
    required this.issues,
    required this.showWeekend,
    required this.jiraApiClient,
    required this.loadIssues,
    required this.onUpdateIssue,
  }) : super(key: key);

  @override
  State<TimesheetTable> createState() => _TimesheetTableState();
}

class _TimesheetTableState extends State<TimesheetTable> {
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  bool _isLoading = false;
  final _colKeyWidth = 100.0;
  final _colDataWidth = 70.0;

  @override
  void initState() {
    super.initState();
    _reloadIssues();
  }

  void _reloadIssues() {
    setState(() => _isLoading = true);
    widget.loadIssues(formatDate(_currentWeekStart), formatDate(_currentWeekStart.add(const Duration(days: 6)))).then((value) {
      setState(() => _isLoading = false);
    });
  }

  // Build columns dynamically, including weekend columns conditionally
  List<DataColumn> _buildColumns(List<int> dayNumbers, double colSummaryWidth) {
    List<DataColumn> columns = [
      DataColumn(
        label: SizedBox(
          width: _colKeyWidth,
          child: const Text('Key'),
        ),
      ),
      DataColumn(label: SizedBox(width: colSummaryWidth, child: const Text('Summary'))),
      _buildColumnHeaderCell('${dayNumbers[0]}\nMon', 0),
      _buildColumnHeaderCell('${dayNumbers[1]}\nTue', 1),
      _buildColumnHeaderCell('${dayNumbers[2]}\nWed', 2),
      _buildColumnHeaderCell('${dayNumbers[3]}\nThu', 3),
      _buildColumnHeaderCell('${dayNumbers[4]}\nFri', 4),
    ];

    if (widget.showWeekend) {
      columns.addAll([
        _buildColumnHeaderCell('${dayNumbers[5]}\nSat', 5),
        _buildColumnHeaderCell('${dayNumbers[6]}\nSun', 6),
      ]);
    }

    return columns;
  }

  DataColumn _buildColumnHeaderCell(String value, int dayNumber) {
    return DataColumn(
      label: Container(
        width: _colDataWidth,
        color: isToday(_currentWeekStart, dayNumber) ? Colors.blueGrey.shade100 : null,
        child: Text(value, textAlign: TextAlign.center),
      ),
    );
  }

  // Build rows dynamically, including weekend data cells conditionally
  List<DataRow> _buildRows(double colSummaryWidth) {
    List<DataRow> rows = widget.issues.map((issue) {
      var worklogMinutesByDay = issue.getWorklogMinutesByWeekday(_currentWeekStart);
      List<DataCell> cells = [
        DataCell(
          SizedBox(
            width: _colKeyWidth,
            child: InkWell(
              onTap: () => openIssueUrl(issue.key),
              child: Text(
                issue.key,
                style: const TextStyle(
                  color: Colors.blue, // Use a text color that indicates interactivity
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: colSummaryWidth,
            child: Text(
              issue.fields.summary,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              maxLines: 1,
            ),
          ),
        ),
        _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 0)), worklogMinutesByDay['Monday']!),
        _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 1)), worklogMinutesByDay['Tuesday']!),
        _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 2)), worklogMinutesByDay['Wednesday']!),
        _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 3)), worklogMinutesByDay['Thursday']!),
        _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 4)), worklogMinutesByDay['Friday']!),
      ];

      if (widget.showWeekend) {
        cells.addAll([
          _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 5)), worklogMinutesByDay['Saturday']!),
          _buildWorklogCell(issue, _currentWeekStart.add(const Duration(days: 6)), worklogMinutesByDay['Sunday']!),
        ]);
      }

      return DataRow(cells: cells);
    }).toList();

    // Add the total row
    var totalWorklog = _computeTotalWorklogByDay();
    List<DataCell> totalCells = [
      DataCell(SizedBox(width: _colKeyWidth, child: const Text(''))), // Empty cell for 'Key' column
      DataCell(SizedBox(width: colSummaryWidth, child: const Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)))),
    ];

    totalCells.addAll([
      _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Monday']!), 0),
      _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Tuesday']!), 1),
      _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Wednesday']!), 2),
      _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Thursday']!), 3),
      _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Friday']!), 4),
    ]);

    if (widget.showWeekend) {
      totalCells.addAll([
        _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Saturday']!), 5),
        _buildTotalCell(Issue.getFormattedWorklogTime(totalWorklog['Sunday']!), 6),
      ]);
    }

    rows.add(DataRow(cells: totalCells));

    return rows;
  }

  DataCell _buildWorklogCell(Issue issue, DateTime date, int minutes) {
    return DataCell(
      Container(
        color: isToday(date) ? Colors.blueGrey.shade50 : null,
        width: _colDataWidth,
        child: TextButton(
          onPressed: () => _showWorklogDetailDialog(context, issue, date),
          child: Text(Issue.getFormattedWorklogTime(minutes)),
        ),
      ),
    );
  }

  DataCell _buildTotalCell(String value, int dayNumber) {
    return DataCell(
      Container(
        color: isToday(_currentWeekStart, dayNumber) ? Colors.blueGrey.shade100 : null,
        width: _colDataWidth,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _showWorklogDetailDialog(BuildContext context, Issue issue, DateTime date) async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return WorklogDetailDialog(
          issue: issue,
          date: date,
          jiraApiClient: widget.jiraApiClient,
        );
      },
    );
    var action = result == null ? 'cancel' : result['action'] ?? 'cancel';
    if (action == 'add') {
      setState(() {
        issue.fields.worklog.worklogs.add(WorklogEntry.fromMap(result['result']));
      });
    } else if (action == 'save') {
      WorklogEntry worklogEntry = WorklogEntry.fromMap(result['result']);
      setState(() {
        //replace worklog entry
        replaceWorklogEntry(issue.fields.worklog, worklogEntry);
      });
    } else if (action == 'delete') {
      setState(() {
        removeWorklogEntry(issue.fields.worklog, result['result']);
      });
    }
  }

  Map<String, int> _computeTotalWorklogByDay() {
    Map<String, int> totalWorklog = {
      'Monday': 0,
      'Tuesday': 0,
      'Wednesday': 0,
      'Thursday': 0,
      'Friday': 0,
      'Saturday': 0,
      'Sunday': 0,
    };

    for (var issue in widget.issues) {
      var worklogMinutesByDay = issue.getWorklogMinutesByWeekday(_currentWeekStart);
      totalWorklog.keys.forEach((day) {
        totalWorklog[day] = totalWorklog[day]! + (worklogMinutesByDay[day] ?? 0);
      });
    }

    return totalWorklog;
  }

  void _moveWeek(bool next) {
    setState(() {
      if (next) {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      } else {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      }
      _reloadIssues();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the current month's name
    String monthName = DateFormat('MMMM').format(_currentWeekStart);
    // Generate day numbers for the current week
    List<int> dayNumbers = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)).day);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_left),
                        label: const Text('prev'),
                        onPressed: () => _moveWeek(false),
                      ),
                      Text(
                        monthName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_right),
                        label: const Text('next'),
                        onPressed: () => _moveWeek(true),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Calculate the total width for all columns except the second column
                    double totalFixedWidth = _colKeyWidth + (_colDataWidth * (widget.showWeekend ? 7 : 5)) + 160;

                    // Calculate the width for the second column
                    double colSummaryWidth = constraints.maxWidth - totalFixedWidth;

                    return DataTable(
                      columnSpacing: 10,
                      dataRowHeight: 30,
                      headingRowHeight: 43,
                      columns: _buildColumns(dayNumbers, colSummaryWidth),
                      rows: _buildRows(colSummaryWidth),
                      // sortAscending: true,
                      // sortColumnIndex: 0,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(255, 116, 116, 116).withOpacity(0.2), // Semi-transparent overlay
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
