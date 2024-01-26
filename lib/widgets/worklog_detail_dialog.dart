import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/issue.dart';
import '../services/jira_api_client.dart';
import '../utils/custom_shared_preferences.dart';
import '../utils/dateformat.dart';

class WorklogDetailDialog extends StatefulWidget {
  final Issue issue;
  final DateTime date;
  final JiraApiClient jiraApiClient;

  const WorklogDetailDialog({
    Key? key,
    required this.issue,
    required this.date,
    required this.jiraApiClient,
  }) : super(key: key);

  @override
  _WorklogDetailDialogState createState() => _WorklogDetailDialogState();
}

class _WorklogDetailDialogState extends State<WorklogDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  late MaskTextInputFormatter _timeFormatter;
  late WorklogEntry _worklogEntry;
  late String _remainingEstimate;
  late String _remainingOption;
  late bool _isNewWorklogEntry;
  bool _isLoading = false;

  final Map<String, String> _remainingOptions = {
    'new': 'Sets the estimate to a specific value',
    'leave': 'Leaves the estimate as is',
    'manual': 'Specify a specific amount to increase remaining estimate by',
    'auto': 'Automatically adjust the value based on the new Time Spent specified on the worklog'
  };

  @override
  void initState() {
    super.initState();
    _newWorklogEntry();
    //_loadSettings();
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _worklogEntry.timeSpentSeconds = prefs.getInt('${widget.issue.key}_timeSpentSeconds') ?? 0;
      _worklogEntry.comment = prefs.getString('${widget.issue.key}_comment') ?? '';
    });
  }

  _saveSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('${widget.issue.key}_timeSpentSeconds', _worklogEntry.timeSpentSeconds);
      prefs.setString('${widget.issue.key}_comment', _worklogEntry.comment);
    } else {
      // Handle the scenario when local storage is not available
      throw Exception("local storage is disabled");
    }
  }

  void _newWorklogEntry() {
    setState(() {
      _worklogEntry = WorklogEntry(
        self: '',
        id: 0,
        comment: '',
        started: DateTime.now(),
        timeSpent: '0',
        timeSpentSeconds: 0,
        issueId: widget.issue.id,
        author: null,
        updateAuthor: null,
      );
      _timeFormatter = MaskTextInputFormatter(mask: '##:##');
      _isNewWorklogEntry = true;
      _remainingEstimate = '00:00';
      _remainingOption = 'auto';
    });
  }

  bool _validateTime(String value) {
    final timeParts = value.split(':').map(int.parse).toList();
    if (timeParts[0] < 24 && timeParts[1] < 60) {
      return true;
    }
    return false;
  }

  bool _validateRemainingTime(String value) {
    final timeParts = value.split(':').map(int.parse).toList();
    if (timeParts[0] < 100 && timeParts[1] < 60) {
      return true;
    }
    return false;
  }

  DateTime _getDateTimeFromStartTime(String startTime) {
    final parts = startTime.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid start time format');
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      throw Exception('Invalid start time format');
    }

    return DateTime(widget.date.year, widget.date.month, widget.date.day, hour, minute);
  }

  void _saveWorklog() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      //_saveSettings();
      try {
        dynamic result = await widget.jiraApiClient.upInsertWorklogEntry(
          worklogEntry: _worklogEntry,
          adjustEstimate: _remainingOption,
          newEstimate: _remainingEstimate,
        );
        // Pass the updated issue object when popping the screen
        if (_worklogEntry.id == 0) {
          //add new
          Navigator.of(context).pop({'action': 'add', 'result': result});
        } else {
          Navigator.of(context).pop({'action': 'save', 'result': result});
        }
      } catch (e) {
        _worklogEntry = await _reloadWorklogEntry(_worklogEntry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving worklog: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editWorklog(WorklogEntry worklogEntry) async {
    if (worklogEntry.comment.isEmpty && widget.issue.expand == 'tempo-timesheets') {
      try {
        worklogEntry = await _reloadWorklogEntry(worklogEntry);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reloading worklog entry: $e')),
        );
      }
    }
    setState(() {
      _worklogEntry = worklogEntry;
      _isNewWorklogEntry = false;
    });
  }

  Future<WorklogEntry> _reloadWorklogEntry(WorklogEntry worklogEntry) async {
    try {
      setState(() => _isLoading = true);
      dynamic result = await widget.jiraApiClient.getWorklogEntry(widget.issue.id, worklogEntry.id);
      return WorklogEntry.fromMap(result);
    } catch (e) {
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteWorklog() async {
    try {
      setState(() => _isLoading = true);
      await widget.jiraApiClient.deleteWorklogEntry(
        issueKey: widget.issue.key,
        worklogId: _worklogEntry.id,
      );
      Navigator.of(context).pop({'action': 'delete', 'result': _worklogEntry.id}); // Return 'delete' when deleted
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving worklog: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_isLoading,
        onPopInvoked: (didPop) => () {
              Navigator.of(context).pop({'action': 'cancel', 'result': null}); // Return 'cancel' when the dialog is dismissed without saving or deleting
              return true; // Returning true allows the dialog to be closed
            },
        child: AlertDialog(
          title: Text('Worklog ${widget.issue.key}'),
          contentPadding: const EdgeInsets.all(15),
          titlePadding: const EdgeInsets.only(top: 10, left: 15),
          actionsPadding: const EdgeInsets.only(bottom: 10, right: 20, left: 20),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: [Text(widget.issue.fields.summary), const Spacer(), Text(formatDate(widget.date))],
              ),
              Stack(children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildWorklogsList(),
                        const SizedBox(height: 20),
                        _buildFormContent(),
                      ],
                    ),
                  ),
                ),
                if (_isLoading) _buildLoadingOverlay(),
              ]),
            ],
          ),
          actions: _isNewWorklogEntry ? _buildNewEntryActions() : _buildExistingEntryActions(),
        ));
  }

  Widget _buildWorklogsList() {
    return Column(
      children: widget.issue.fields.worklog.worklogs.where((worklogEntry) {
        // Check if the worklog's date matches widget.date
        return DateFormat('yyyy-MM-dd').format(worklogEntry.started) == DateFormat('yyyy-MM-dd').format(widget.date);
      }).map((worklogEntry) {
        String comment = worklogEntry.comment.isNotEmpty ? worklogEntry.comment.split('\n').first : 'no comment';
        return Row(children: [
          const SizedBox(width: 20, child: Icon(Icons.watch_later_outlined, size: 15, color: Color.fromRGBO(162, 0, 190, 1))),
          Flexible(
            // Wrapping the comment text inside Flexible
            child: Text(
              '${formatDateTimeToHHMM(worklogEntry.started)} (${worklogEntry.timeSpent}) - $comment', // Get only the first line of the comment
              overflow: TextOverflow.ellipsis, // Adding ellipsis overflow
              softWrap: false, // Prevents line wrapping
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: SizedBox(
              width: 22,
              height: 22,
              child: RawMaterialButton(
                onPressed: () => _editWorklog(worklogEntry), //edit worklog entry
                elevation: 2.0,
                fillColor: Colors.purple.shade200,
                padding: const EdgeInsets.all(00),
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.edit,
                  size: 15,
                ),
              ),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                inputFormatters: [_timeFormatter],
                decoration: const InputDecoration(
                  hintText: 'HH:MM',
                  labelText: 'Time Spent',
                ),
                controller: TextEditingController(text: getSpentTimeFormatted(_worklogEntry.timeSpentSeconds)),
                validator: (value) {
                  if (value == null || value.isEmpty || !_validateTime(value)) {
                    return 'Please enter valid time (hh:mm)';
                  }
                  return null;
                },
                onSaved: (value) => _worklogEntry.timeSpentSeconds = getSecondsFromHHmm(value!),
              ),
            ),
            const SizedBox(width: 10), // give it width
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'HH:MM',
                  labelText: 'Start Time',
                ),
                controller: TextEditingController(text: formatTimeOfDay(_worklogEntry.started)),
                inputFormatters: [_timeFormatter],
                validator: (value) {
                  if (value == null || value.isEmpty || !_validateTime(value)) {
                    return 'Please enter valid time (hh:mm)';
                  }
                  return null;
                },
                onSaved: (value) => _worklogEntry.started = _getDateTimeFromStartTime(value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10), // give it some space
        Row(
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'Adjust Estimate',
                ),
                value: _remainingOption,
                onChanged: (String? newValue) {
                  setState(() {
                    _remainingOption = newValue!;
                  });
                },
                items: _remainingOptions.keys.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10), // give it width
            SizedBox(
              width: 200,
              child: _remainingOption != 'auto' && _remainingOption != 'leave'
                  ? TextFormField(
                      inputFormatters: [_timeFormatter],
                      decoration: const InputDecoration(
                        hintText: 'HH:MM',
                        labelText: 'Remaining Estimate',
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && !_validateRemainingTime(value)) {
                          return 'Please enter valid time (hh:mm) - less than 100 hours';
                        }
                        return null;
                      },
                      onSaved: (value) => _remainingEstimate = value!,
                    )
                  : null,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_remainingOptions[_remainingOption] ?? ''),
        ),
        TextFormField(
          decoration: const InputDecoration(
            hintText: 'Comments',
            labelText: 'Description',
          ),
          controller: TextEditingController(text: _worklogEntry.comment),
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 5,
          onSaved: (value) => _worklogEntry.comment = value!,
        )
      ]),
    );
  }

  List<Widget> _buildNewEntryActions() {
    return <Widget>[
      TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.blueGrey.shade200,
        ),
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Add worklog'),
        onPressed: _isLoading ? null : () => _saveWorklog(),
      ),
    ];
  }

  List<Widget> _buildExistingEntryActions() {
    return <Widget>[
      Row(children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 241, 227, 227),
            foregroundColor: Colors.red,
            disabledForegroundColor: Colors.blueGrey.shade200,
          ),
          icon: const Icon(Icons.delete, color: Colors.red),
          label: const Text('Delete'),
          onPressed: _isLoading ? null : () => _deleteWorklog(),
        ),
        const Spacer(),
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 253, 254, 255),
            disabledForegroundColor: Colors.blueGrey.shade200,
            //foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.plus_one),
          label: const Text('New worklog'),
          onPressed: _isLoading ? null : () => _newWorklogEntry(),
        ),
        const Spacer(),
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.blueGrey.shade200,
          ),
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text('Save'),
          onPressed: _isLoading ? null : () => _saveWorklog(),
        ),
      ]),
    ];
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color.fromARGB(255, 116, 116, 116).withOpacity(0.2), // Semi-transparent overlay
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
