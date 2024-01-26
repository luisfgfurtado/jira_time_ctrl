import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/issue.dart';
import '../utils/issue_utilities.dart';

class IssueCard extends StatefulWidget {
  final Issue issue;

  const IssueCard({Key? key, required this.issue}) : super(key: key);

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  void _moveWeek(bool next) {
    setState(() {
      if (next) {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      } else {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      }
    });
  }

  Widget _buildWorklogTable() {
    var worklogMinutesByDay = widget.issue.getWorklogMinutesByWeekday(_currentWeekStart);

    // Get the current month's name
    String monthName = DateFormat('MMMM').format(_currentWeekStart);

    // Generate day numbers for the current week
    List<int> dayNumbers = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)).day);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => _moveWeek(false),
            ),
            Text(
              monthName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => _moveWeek(true),
            ),
          ],
        ),
        DataTable(
          columns: [
            DataColumn(label: Text('Mon\n${dayNumbers[0]}')),
            DataColumn(label: Text('Tue\n${dayNumbers[1]}')),
            DataColumn(label: Text('Wed\n${dayNumbers[2]}')),
            DataColumn(label: Text('Thu\n${dayNumbers[3]}')),
            DataColumn(label: Text('Fri\n${dayNumbers[4]}')),
            DataColumn(label: Text('Sat\n${dayNumbers[5]}')),
            DataColumn(label: Text('Sun\n${dayNumbers[6]}')),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Monday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Tuesday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Wednesday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Thursday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Friday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Saturday']!))),
                DataCell(Text(Issue.getFormattedWorklogTime(worklogMinutesByDay['Sunday']!))),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String totalWorklogTime = Issue.getFormattedWorklogTime(widget.issue.getTotalMinutes());

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.issue.key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => openIssueUrl(widget.issue.key), // Use the utility function
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              // Issue Summary
              child: Text(widget.issue.fields.summary),
            ),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16), // Clock Icon
                const SizedBox(width: 4), // Spacing between icon and text
                Text(totalWorklogTime), // Total Worklog Hours
              ],
            ),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildWorklogTable(),
          ),
        ],
      ),
    );
  }
}
