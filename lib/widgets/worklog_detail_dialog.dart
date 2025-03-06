import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jira_time_ctrl/models/custom_attribute.dart';
import 'package:jira_time_ctrl/models/my_timesheet_info.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import '../models/issue.dart';
import '../services/jira_api_client.dart';
//import '../utils/custom_shared_preferences.dart';
import '../utils/custom_shared_preferences.dart';
import '../utils/dateformat.dart';

class WorklogDetailDialog extends StatefulWidget {
  final Issue issue;
  final DateTime date;
  final JiraApiClient jiraApiClient;
  final MyTimesheetInfo myTimesheetInfo;
  final int totalWorklogMinutes;

  const WorklogDetailDialog({
    Key? key,
    required this.issue,
    required this.date,
    required this.jiraApiClient,
    required this.myTimesheetInfo,
    this.totalWorklogMinutes = 0,
  }) : super(key: key);

  @override
  WorklogDetailDialogState createState() => WorklogDetailDialogState();
}

class WorklogDetailDialogState extends State<WorklogDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  final MaskTextInputFormatter _timeFormatter = MaskTextInputFormatter(mask: '##:##');
  final _timeSpentController = TextEditingController();
  final _startTimeController = TextEditingController();
  Map<String, TextEditingController> controllers = {};
  Map<String, bool> _checkboxValues = {};
  final FocusNode _timeSpentFocusNode = FocusNode();
  final FocusNode _startTimeFocusNode = FocusNode();
  late WorklogEntry _worklogEntry;
  late String _remainingEstimate;
  late String _remainingOption;
  bool _isNewWorklogEntry = true;
  List<String> _commentHistory = [];
  int _stdHoursDay = 8;
  bool _isLoading = true;

  final Map<String, String> _remainingOptions = {
    'new': 'Sets the estimate to a specific value',
    'leave': 'Leaves the estimate as is',
    'manual': 'Specify a specific amount to increase remaining estimate by',
    'auto': 'Automatically adjust the value based on the new Time Spent specified on the worklog'
  };

  @override
  void initState() {
    super.initState();

    // Initialize and set up listeners for time spent
    _setupTimeController(_timeSpentController, _timeSpentFocusNode);

    // Initialize and set up listeners for start time
    _setupTimeController(_startTimeController, _startTimeFocusNode);

    _initializeCheckboxValues();
    _initializeDropdownControllers();

    _generalInit();
  }

  @override
  void dispose() {
    _timeSpentController.dispose();
    _startTimeController.dispose();
    _timeSpentFocusNode.dispose();
    _startTimeFocusNode.dispose();
    super.dispose();
  }

  _generalInit() async {
    await _loadSettings();
    _newWorklogEntry();
    setState(() => _isLoading = false);
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      //_worklogEntry.timeSpentSeconds = prefs.getInt('${widget.issue.key}_timeSpentSeconds') ?? 0;
      _commentHistory = prefs.getStringList('${widget.issue.key}_comment_history') ?? [];
      _stdHoursDay = prefs.getInt('stdHoursDay') ?? _stdHoursDay;
    });
  }

  void _initializeCheckboxValues() {
    for (var attr in widget.myTimesheetInfo.customAttributes) {
      if (attr.type == "Checkbox") {
        _checkboxValues[attr.key] = false; // Inicializa todos os checkboxes como desmarcados
      }
    }
  }

  void _initializeDropdownControllers() {
    for (var attr in widget.myTimesheetInfo.customAttributes) {
      if (attr.type == "List") {
        controllers[attr.key] = TextEditingController();
      }
    }
  }

  _saveSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      //prefs.setInt('${widget.issue.key}_timeSpentSeconds', _worklogEntry.timeSpentSeconds);
      prefs.setStringList('${widget.issue.key}_comment_history', _commentHistory);
    } else {
      // Handle the scenario when local storage is not available
      throw Exception("local storage is disabled");
    }
  }

  void _newWorklogEntry() {
    int timeSpentSeconds = _stdHoursDay > 0 && widget.totalWorklogMinutes < _stdHoursDay * 60 ? ((_stdHoursDay * 60) - widget.totalWorklogMinutes) * 60 : 0;
    setState(() {
      _worklogEntry = WorklogEntry(
        self: '',
        id: 0,
        comment: '',
        started: DateTime.now(),
        timeSpent: '0',
        timeSpentSeconds: timeSpentSeconds,
        issueId: widget.issue.id,
        author: null,
        updateAuthor: null,
      );
      _isNewWorklogEntry = true;
      _remainingEstimate = '00:00';
      _remainingOption = 'auto';
      _timeSpentController.text = getSpentTimeFormatted(_worklogEntry.timeSpentSeconds);
      _startTimeController.text = formatTimeOfDay(_worklogEntry.started);
    });
  }

  void _setupTimeController(TextEditingController controller, FocusNode focusNode) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      } else {
        _formatTimeText(controller);
      }
    });

    controller.addListener(() {
      String currentText = controller.text.replaceAll(':', '');

      // Limit to 4 digits
      if (currentText.length > 4) {
        currentText = currentText.substring(0, 4);
      }

      // Insert colon after the first two digits
      if (currentText.length > 2) {
        if (currentText.length < 4) {
          currentText = '${currentText.substring(0, 1)}:${currentText.substring(1)}';
        } else {
          currentText = '${currentText.substring(0, 2)}:${currentText.substring(2)}';
        }
      }

      if (controller.text != currentText) {
        controller.value = TextEditingValue(
          text: currentText,
          selection: TextSelection.collapsed(offset: currentText.length),
        );
      }
    });
  }

  void _formatTimeText(TextEditingController controller) {
    //controller.removeListener(() => _controllerListener(controller));
    String currentText = controller.text.replaceAll(':', '');

    if (currentText.length > 4) {
      // Truncate to 4 characters to ensure HH:MM format
      currentText = currentText.substring(0, 4);
    }

    while (currentText.length < 4) {
      // Prepend zeros to the left to make it 4 digits
      currentText = '0$currentText';
    }

    // Split the string into hour and minute parts
    String hourPart = currentText.substring(0, 2);
    String minutePart = currentText.substring(2);

    // Validate hour and minute parts
    int hour = int.tryParse(hourPart) ?? 0;
    int minute = int.tryParse(minutePart) ?? 0;

    if (hour > 23) hour = 23; // Limit hour to 23
    if (minute > 59) {
      if (hour > 0) {
        minute = 59; // Limit minute to 59
      } else {
        hour = 1;
        minute = minute - 60; // Convert minutes to time
      }
    }

    // Reconstruct the formatted time text
    String formattedText = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    controller.text = formattedText;

    // Add the listener back
    //controller.addListener(() => _controllerListener(controller));
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

      // Inicializa a lista se for null
      _worklogEntry.customAttributeValues ??= [];

      // Coletar e adicionar/atualizar valores dos custom attributes
      for (var attr in widget.myTimesheetInfo.customAttributes) {
        if (attr.active && (attr.projectScope == null || attr.projectScope!.contains(widget.issue.fields.projectKey))) {
          // Obter valor do formulário
          var value = _getCustomAttributeValueFromForm(attr.key, attr.type);
          if (value == null) continue;

          // Encontrar ou criar um novo CustomAttributeValue
          var existingAttr = _worklogEntry.customAttributeValues?.firstWhere((a) => a.customAttributeID == attr.id,
              orElse: () => CustomAttributeValue(
                    customAttributeKey: '',
                    customAttributeID: -1, // Use um ID inválido ou zero para indicar um novo valor
                    worklogId: _worklogEntry.id,
                    worklogDate: _worklogEntry.started,
                    value: '',
                    id: null,
                  ));

          if (existingAttr?.customAttributeID == -1) {
            // Adicionar novo valor se não existir
            _worklogEntry.customAttributeValues ??= []; // Garante que a lista foi inicializada
            _worklogEntry.customAttributeValues!.add(CustomAttributeValue(
              customAttributeKey: attr.key,
              customAttributeID: attr.id,
              worklogId: _worklogEntry.id,
              worklogDate: _worklogEntry.started,
              value: value,
              id: null, // Suponha que id é gerado pelo servidor ou não necessário
            ));
          } else {
            // Atualizar valor existente
            existingAttr?.value = value;
          }
        }
      }

      // Add the worklog comment to local comment history, to be used in future worklogs
      if (!_commentHistory.contains(_worklogEntry.comment)) {
        _commentHistory.add(_worklogEntry.comment);
        if (_commentHistory.length > 5) _commentHistory.removeAt(0); // Remove the oldest entry
      }
      _saveSettings();
      try {
        //update worklog
        dynamic result = await widget.jiraApiClient.upInsertWorklogEntry(
          worklogEntry: _worklogEntry,
          adjustEstimate: _remainingOption,
          newEstimate: _remainingEstimate,
        );
        //update custom attributes
        if (_worklogEntry.customAttributeValues!.isNotEmpty && result['id'] != null) {
          await widget.jiraApiClient.upInsertWorklogCustomAttributes(worklogEntry: _worklogEntry, worklogId: int.parse(result['id']));
        }

        if (!mounted) return; // check ensures widget is still present in the widget tree
        // Pass the updated issue object when popping the screen
        if (_worklogEntry.id == 0) {
          //add new
          Navigator.of(context).pop({'action': 'add', 'result': result});
        } else {
          Navigator.of(context).pop({'action': 'save', 'result': result});
        }
      } catch (e) {
        if (_worklogEntry.id != 0) {
          _worklogEntry = await _reloadWorklogEntry(_worklogEntry);
        }
        if (!mounted) return; // check ensures widget is still present in the widget tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving worklog: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  dynamic _getCustomAttributeValueFromForm(String attributeKey, String attributeType) {
    if (attributeType == "List") {
      return controllers[attributeKey]?.text; // Retorna o texto atual do Dropdown
    } else if (attributeType == "Checkbox") {
      return _checkboxValues[attributeKey]; // Retorna o valor booleano do Checkbox
    }
    return null;
  }

  void _editWorklog(WorklogEntry worklogEntry) async {
    if (worklogEntry.comment.isEmpty && widget.issue.expand == 'tempo-timesheets') {
      try {
        worklogEntry = await _reloadWorklogEntry(worklogEntry);
      } catch (e) {
        if (!mounted) return; // Verifica se o widget ainda está presente na árvore de widgets
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reloading worklog entry: $e')),
        );
        return; // Retorna cedo se houver um erro
      }
    }

    if (worklogEntry.customAttributeValues != null) {
      // Limpa valores anteriores nos controllers e checkbox values
      controllers.forEach((key, controller) {
        controller.clear();
      });
      _checkboxValues.forEach((key, value) {
        _checkboxValues[key] = false;
      });

      // Carrega novos valores nos controllers ou checkbox values apropriados
      for (var customValue in worklogEntry.customAttributeValues!) {
        var attr = widget.myTimesheetInfo.customAttributes.firstWhere((a) => a.id == customValue.customAttributeID,
            orElse: () => CustomAttribute(
                  active: false,
                  id: -1, // Use um valor que indique que é um placeholder
                  label: "Undefined",
                  projectScope: null,
                  type: "None",
                  config: {},
                  key: "undefined",
                  required: false,
                )); // Retorna um CustomAttribute de placeholder se não encontrar

        if (attr != null && attr.id != -1) {
          if (attr.type == "List") {
            controllers[attr.key]?.text = customValue.value.toString();
          } else if (attr.type == "Checkbox") {
            _checkboxValues[attr.key] = bool.parse(customValue.value);
          }
        }
      }
    }

    setState(() {
      _worklogEntry = worklogEntry;
      _isNewWorklogEntry = false;
      _timeSpentController.text = getSpentTimeFormatted(_worklogEntry.timeSpentSeconds);
      _startTimeController.text = formatTimeOfDay(_worklogEntry.started);
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
      if (!mounted) return; // check ensures widget is still present in the widget tree
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Rounded corners
          ),
          title: Text('Worklog ${widget.issue.key}'),
          contentPadding: const EdgeInsets.all(15),
          titlePadding: const EdgeInsets.only(top: 10, left: 15),
          actionsPadding: const EdgeInsets.only(bottom: 10, right: 20, left: 20),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: [Text(widget.issue.fields.summary), const Spacer(), Text(formatDate2(widget.date))],
              ),
              Stack(children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 20),
                    child: Column(
                      children: [
                        _buildWorklogsList(),
                        const SizedBox(height: 10),
                        if (_isLoading)
                          AbsorbPointer(
                            child: Container(
                              color: Colors.black.withOpacity(0.5),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            ),
                          )
                        else
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
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
      ),
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
                decoration: const InputDecoration(
                  hintText: 'HH:MM',
                  labelText: 'Time Spent',
                ),
                controller: _timeSpentController,
                focusNode: _timeSpentFocusNode,
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
                controller: _startTimeController,
                focusNode: _startTimeFocusNode,
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
          child: Text(_remainingOptions[_remainingOption] ?? '', style: const TextStyle(fontSize: 10)),
        ),
        Stack(
          children: [
            //Position the TextField at the bottom
            Positioned(
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Comments',
                  labelText: 'Description',
                ),
                controller: TextEditingController(text: _worklogEntry.comment),
                keyboardType: TextInputType.multiline,
                minLines: 2,
                maxLines: 5,
                onSaved: (value) => _worklogEntry.comment = value!,
              ),
            ),
            // Overlay the button on top
            _commentHistory.isNotEmpty
                ? Positioned(
                    right: 10.0, // Adjust right and top paddings as needed
                    top: 10.0,
                    child: FloatingActionButton(
                      mini: true,
                      elevation: 0,
                      child: const Icon(Icons.history),
                      onPressed: () {
                        // Show a modal bottom sheet with the comment history
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => ListView.separated(
                            separatorBuilder: (context, index) => const Divider(height: 1), // Add a divider between items
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _commentHistory.length,
                            itemBuilder: (context, index) {
                              final comment = _commentHistory[index];
                              return OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _worklogEntry.comment = comment;
                                  });
                                  Navigator.pop(context); // Close the bottom sheet
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: const ContinuousRectangleBorder(),
                                  side: const BorderSide(style: BorderStyle.none),
                                ),
                                child: Text(comment),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox(width: 12),
          ],
        ),
        ..._buildCustomAttributesForm()
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
          icon: const Icon(Icons.add),
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

  List<Widget> _buildCustomAttributesForm() {
    List<Widget> fields = [];
    for (var attr in widget.myTimesheetInfo.customAttributes
        .where((attr) => attr.active && (attr.projectScope == null || attr.projectScope!.contains(widget.issue.fields.projectKey)))) {
      if (attr.type == "List") {
        var options = List<String>.from(attr.config['options'] as List);
        String? selectedValue = controllers[attr.key]?.text; // Pode ser null inicialmente
        if (!options.contains(selectedValue)) {
          selectedValue = null; // Isso garante que o valor inicial esteja na lista de opções ou seja nulo
        }
        fields.add(Row(children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: attr.label),
              value: selectedValue,
              onChanged: (String? newValue) {
                setState(() {
                  controllers[attr.key]?.text = newValue ?? '';
                });
              },
              items: options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          )
        ]));
      } else if (attr.type == "Checkbox") {
        fields.add(Row(children: [
          SizedBox(
            width: 200,
            child: CheckboxListTile(
              title: Text(attr.label),
              value: _checkboxValues[attr.key], // Usa o mapa para definir o valor
              dense: true,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    _checkboxValues[attr.key] = value;
                  });
                }
              },
            ),
          )
        ]));
      }
    }
    return fields;
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
