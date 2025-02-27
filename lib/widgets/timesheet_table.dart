import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jira_time_ctrl/models/issue_utils.dart';
import 'package:jira_time_ctrl/models/my_timesheet_info.dart';
import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/dateformat.dart';
import '../utils/issue_utilities.dart';
import 'worklog_detail_dialog.dart';

class TimesheetTable extends StatefulWidget {
  final Future<void> Function(String, String) loadIssues; // Load issues
  final Future<void> Function(String) onUpdateIssue; // Add this
  final List<Issue> issues;
  final List<Issue> filteredIssues;
  final bool showWeekend;
  final JiraApiClient jiraApiClient;
  final MyTimesheetInfo myTimesheetInfo;
  final int tempoWorklogsPeriod;

  const TimesheetTable({
    Key? key,
    required this.issues,
    required this.filteredIssues,
    required this.showWeekend,
    required this.jiraApiClient,
    required this.myTimesheetInfo,
    required this.loadIssues,
    required this.onUpdateIssue,
    required this.tempoWorklogsPeriod,
  }) : super(key: key);

  @override
  State<TimesheetTable> createState() => _TimesheetTableState();
}

class _TimesheetTableState extends State<TimesheetTable> {
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  bool _todaysWeek = true;
  bool _isLoading = false;
  final _colKeyWidth = 100.0;
  final _colDataWidth = 70.0;
  late Map<String, int> _totalWorklog;

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
        color: isToday(_currentWeekStart, dayNumber) ? Theme.of(context).primaryColor : null,
        child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: isToday(_currentWeekStart, dayNumber) ? Colors.white : null)),
      ),
    );
  }

  // Build rows dynamically, including weekend data cells conditionally
  List<DataRow> _buildRows(BuildContext context, double colSummaryWidth) {
    int i = 0;
    List<DataRow> rows = widget.filteredIssues.map((issue) {
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
                  //decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: issue.fields.assignee.me
                    ? Icon(
                        Icons.account_circle_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 14,
                      )
                    : const SizedBox(width: 14),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: colSummaryWidth,
                child: Text(
                  issue.fields.summary,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  maxLines: 1,
                ),
              ),
            ],
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
      i++;
      return DataRow(
        color: i.isOdd ? MaterialStateColor.resolveWith((states) => Colors.grey.shade100) : MaterialStateColor.resolveWith((states) => Colors.white),
        cells: cells,
      );
    }).toList();

    // Add the total row
    _totalWorklog = _computeTotalWorklogByDay();
    List<DataCell> totalCells = [
      DataCell(SizedBox(width: _colKeyWidth, child: const Text(''))), // Empty cell for 'Key' column
      DataCell(SizedBox(width: colSummaryWidth, child: const Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)))),
    ];

    totalCells.addAll([
      _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Monday']!), 0),
      _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Tuesday']!), 1),
      _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Wednesday']!), 2),
      _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Thursday']!), 3),
      _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Friday']!), 4),
    ]);

    if (widget.showWeekend) {
      totalCells.addAll([
        _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Saturday']!), 5),
        _buildTotalCell(Issue.getFormattedWorklogTime(_totalWorklog['Sunday']!), 6),
      ]);
    }

    rows.add(DataRow(cells: totalCells));

    return rows;
  }

  DataCell _buildWorklogCell(Issue issue, DateTime date, int minutes) {
    return DataCell(
      Container(
        color: isToday(date) ? Theme.of(context).primaryColor.withOpacity(0.15) : null,
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
        color: isToday(_currentWeekStart, dayNumber) ? Theme.of(context).primaryColor : null,
        width: _colDataWidth,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: isToday(_currentWeekStart, dayNumber) ? Colors.white : null),
        ),
      ),
    );
  }

  Future<void> _showWorklogDetailDialog(BuildContext context, Issue issue, DateTime date) async {
    String weekday = DateFormat('EEEE').format(date);
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return WorklogDetailDialog(
          issue: issue,
          date: date,
          jiraApiClient: widget.jiraApiClient,
          myTimesheetInfo: widget.myTimesheetInfo,
          totalWorklogMinutes: _totalWorklog[weekday]!,
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
      for (var day in totalWorklog.keys) {
        totalWorklog[day] = totalWorklog[day]! + (worklogMinutesByDay[day] ?? 0);
      }
    }

    return totalWorklog;
  }

  void _gotoToday() {
    setState(() {
      _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      _todaysWeek = true;
    });
  }

  void _moveWeek(bool next) {
    setState(() {
      if (next) {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      } else {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      }
      _reloadIssues();
      _todaysWeek = isDateInCurrentWeek(_currentWeekStart);
    });
  }

  bool isBeforeTempoNLastDays() {
    final DateTime threshold = DateTime.now().subtract(Duration(days: widget.tempoWorklogsPeriod));
    return _currentWeekStart.isBefore(threshold);
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
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: RawMaterialButton(
                          onPressed: () => _moveWeek(false),
                          elevation: 2.0,
                          fillColor: Colors.blueGrey,
                          padding: const EdgeInsets.all(00),
                          shape: const CircleBorder(),
                          child: const Icon(
                            Icons.arrow_left,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 26,
                        child: TextButton(
                          onPressed: _todaysWeek ? null : () => _gotoToday(),
                          style: TextButton.styleFrom(
                            backgroundColor: _todaysWeek ? Colors.blueGrey.shade100 : Colors.blueGrey,
                            foregroundColor: Colors.white,
                          ),
                          child: const Row(
                            children: <Widget>[
                              Icon(Icons.calendar_today, size: 16),
                              SizedBox(width: 5),
                              Text('Today', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        monthName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: RawMaterialButton(
                          onPressed: () => _moveWeek(true),
                          elevation: 2.0,
                          fillColor: Colors.blueGrey,
                          padding: const EdgeInsets.all(00),
                          shape: const CircleBorder(),
                          child: const Icon(
                            Icons.arrow_right,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
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
                      rows: _buildRows(context, colSummaryWidth),
                      // sortAscending: true,
                      // sortColumnIndex: 0,
                    );
                  },
                ),
                if (isBeforeTempoNLastDays())
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.warning, size: 35),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('The current list of issues does not contain issues not assigned to you, even if they have hours reported by you.',
                                      softWrap: true, overflow: TextOverflow.visible),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        const TextSpan(text: 'The current settings load issues with hours reported by you in the last'),
                                        TextSpan(text: ' ${widget.tempoWorklogsPeriod} days', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'This may affect the total hours of each day.',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
