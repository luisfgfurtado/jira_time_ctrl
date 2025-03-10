import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/jira_api_client.dart';
import '../utils/custom_shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final _sourceCodeURL = 'https://github.com/luisfgfurtado/jira_time_ctrl';
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _boardIdController = TextEditingController();
  final _timesheetAddedIssuesController = TextEditingController();
  final _timesheetJQLController = TextEditingController();
  final _tempoWorklogsPeriodController = TextEditingController();
  final _stdHoursDayController = TextEditingController();
  String _jiraApiUrl = '';
  String _jiraApiKey = '';
  String _jiraApiUserKey = '';
  String _jiraBoardId = '';
  String _jiraTimesheetAddedIssues = '';
  bool _jiraJqlHasError = false;
  String _jiraTimesheetJQL = '(worklogDate >= #STARTDATE# AND worklogDate <= #ENDDATE# AND worklogAuthor = currentuser())';
  int _tempoWorklogsPeriod = 21;
  int _stdHoursDay = 8;

  late String _appName;
  late String _packageName;
  late String _version;
  late String _buildNumber;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generalInit();
  }

  _generalInit() async {
    await _loadSettings();
    await _loadAppInfo();
    setState(() => _isLoading = false);
  }

  _loadAppInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    _appName = packageInfo.appName;
    _packageName = packageInfo.packageName;
    _version = packageInfo.version;
    _buildNumber = packageInfo.buildNumber;
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _jiraApiUrl = prefs.getString('jiraApiUrl') ?? _jiraApiUrl;
      _jiraApiKey = prefs.getString('jiraApiKey') ?? _jiraApiKey;
      _jiraApiUserKey = prefs.getString('jiraApiUserKey') ?? _jiraApiUserKey;
      _jiraBoardId = prefs.getString('jiraBoardId') ?? _jiraBoardId;
      _jiraTimesheetAddedIssues = prefs.getString('jiraTimesheetAddedIssues') ?? _jiraTimesheetAddedIssues;
      _jiraTimesheetJQL = prefs.getString('jiraTimesheetJQL') ?? _jiraTimesheetJQL;
      _tempoWorklogsPeriod = prefs.getInt('tempoWorklogsPeriod') ?? _tempoWorklogsPeriod;
      _stdHoursDay = prefs.getInt('stdHoursDay') ?? _stdHoursDay;

      _apiUrlController.text = _jiraApiUrl;
      _apiKeyController.text = _jiraApiKey;
      _boardIdController.text = _jiraBoardId;
      _timesheetAddedIssuesController.text = _jiraTimesheetAddedIssues;
      _timesheetJQLController.text = _jiraTimesheetJQL;
      _tempoWorklogsPeriodController.text = _tempoWorklogsPeriod.toString();
      _stdHoursDayController.text = _stdHoursDay.toString();

      _jiraJqlHasError = prefs.getBool('jiraJqlHasError') ?? false;
    });
  }

  _updateAPIUserKey() async {
    setState(() => _isLoading = true);

    JiraApiClient jiraClient = await JiraApiClient.create();
    _jiraApiUserKey = await jiraClient.getAPIUserKey();
    setState(() => _isLoading = false);
  }

  _saveSettings() async {
    await _updateAPIUserKey();
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('jiraApiUrl', _jiraApiUrl);
      prefs.setString('jiraApiKey', _jiraApiKey);
      prefs.setString('jiraApiUserKey', _jiraApiUserKey);
      prefs.setString('jiraBoardId', _jiraBoardId);
      prefs.setString('jiraTimesheetAddedIssues', _jiraTimesheetAddedIssues);
      prefs.setString('jiraTimesheetJQL', _jiraTimesheetJQL);
      prefs.setBool('jiraJqlHasError', _jiraJqlHasError);
      prefs.setInt('tempoWorklogsPeriod', _tempoWorklogsPeriod);
      prefs.setInt('stdHoursDay', _stdHoursDay);

      // debugPrint("jiraApiUrl: ${prefs.getString('jiraApiUrl')}");
      // debugPrint("jiraApiKey: ${prefs.getString('jiraApiKey')}");
      // debugPrint("jiraBoardId: ${prefs.getString('jiraBoardId')}");
      // debugPrint("jiraTimesheetAddedIssues: ${prefs.getString('jiraTimesheetAddedIssues')}");
      // debugPrint("jiraTimesheetJQL: ${prefs.getString('jiraTimesheetJQL')}");
      // debugPrint("jiraJqlHasError: ${prefs.getBool('jiraJqlHasError')}");
      // debugPrint("tempoWorklogsPeriod: ${prefs.getInt('tempoWorklogsPeriod')}");
      // Use SharedPreferences as usual
    } else {
      // Handle the scenario when local storage is not available
      _showHelpText("local storage is disabled");
    }
  }

  _checkApiConnection() async {
    setState(() => _isLoading = true);

    JiraApiClient jiraClient = await JiraApiClient.create();
    String result = await jiraClient.testConnection();

    setState(() => _isLoading = false);

    _showHelpText(result);
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

  Future<void> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Handle the error or show a message
        throw "Could not launch $uri";
      }
    } catch (e) {
      // Handle any exceptions
      throw "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
            )
          else
            _buildForm(),
        ],
      ),
    );
  }

  Form _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _apiUrlController,
                      decoration: const InputDecoration(labelText: 'Jira API URL'),
                      onChanged: (value) => _jiraApiUrl = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Jira API URL';
                        }
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpText('Enter the URL of your Jira API.\n\nDefault: https://jira.companyname.com/'),
                  ),
                ],
              ),
              const SizedBox(height: 10), // give it some space
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: 'Jira API Key'),
                onChanged: (value) => _jiraApiKey = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Jira API Key';
                  }
                  return null;
                },
              ),
              Text(_jiraApiUserKey),
              const SizedBox(height: 10), // give it some space
              TextFormField(
                controller: _boardIdController,
                decoration: const InputDecoration(labelText: 'Jira Board ID'),
                onChanged: (value) => _jiraBoardId = value,
              ),
              const SizedBox(height: 10), // give it some space
              TextFormField(
                controller: _timesheetAddedIssuesController,
                decoration: const InputDecoration(labelText: 'Timesheet added issues'),
                onChanged: (value) => _jiraTimesheetAddedIssues = value,
              ),
              const SizedBox(height: 10), // give it some space
              TextFormField(
                controller: _timesheetJQLController,
                decoration: const InputDecoration(labelText: 'Timesheet JQL'),
                minLines: 1,
                maxLines: 4,
                onChanged: (value) {
                  _jiraTimesheetJQL = value;
                  _jiraJqlHasError = false;
                },
              ),
              Text('JQL has error status: ${_jiraJqlHasError.toString()}'),
              const SizedBox(height: 20), // give it some space
              TextFormField(
                controller: _tempoWorklogsPeriodController,
                decoration: const InputDecoration(labelText: 'Tempo Worklog Period (last n of days)'),
                onChanged: (value) => _tempoWorklogsPeriod = int.tryParse(value) ?? _tempoWorklogsPeriod,
                validator: (value) {
                  int? v = int.tryParse(value ?? '');
                  if (value == null || value.isEmpty || v == null || v < 7 || v > 60) {
                    return 'Please enter valid number between 7 and 60.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20), // give it some space
              TextFormField(
                controller: _stdHoursDayController,
                decoration: const InputDecoration(labelText: 'Standard Hours per Day (hours)'),
                onChanged: (value) => _stdHoursDay = int.tryParse(value) ?? _stdHoursDay,
                validator: (value) {
                  int? v = int.tryParse(value ?? '');
                  if (value != null && value.isNotEmpty && v == null) {
                    return 'Please enter a integer number of hours.';
                  } else if (value != null && value.isNotEmpty && (v! < 1 || v > 24)) {
                    return 'Please enter valid number between 1 and 24 or leave blank to disable the feature.';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _checkApiConnection,
                      child: const Text('Check API Connection'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _saveSettings();
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text('App name: $_appName\nPackage: $_packageName\nVersion: $_version\nBuild: $_buildNumber'),
              const SizedBox(height: 30),
              const Text('Made by Luis Furtado\nCheck source code:'),
              TextButton(
                child: Text(_sourceCodeURL, style: const TextStyle(color: Colors.blue)),
                onPressed: () => openUrl(_sourceCodeURL), // Use the utility function
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _boardIdController.dispose();
    _timesheetAddedIssuesController.dispose();
    _timesheetJQLController.dispose();

    super.dispose();
  }
}
