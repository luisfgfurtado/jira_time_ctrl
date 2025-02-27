import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/issue.dart';
import '../utils/custom_shared_preferences.dart';

class TempoApiClient {
  late String _apiUrl;
  late String _apiKey;
  late int _tempoWorklogsPeriod;

  TempoApiClient() {
    _loadSettings(); // Call _loadSettings, but don't await here
  }

  static Future<TempoApiClient> create() async {
    var client = TempoApiClient();
    await client._loadSettings(); // Ensure settings are loaded
    return client;
  }

  Future<void> _loadSettings() async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? storedApiUrl = prefs.getString('jiraApiUrl');
      _apiUrl = (storedApiUrl != null && !storedApiUrl.endsWith('/')) ? '$storedApiUrl/' : storedApiUrl ?? '';
      _apiKey = prefs.getString('jiraApiKey') ?? '';
      _tempoWorklogsPeriod = prefs.getInt('tempoWorklogsPeriod') ?? 14;
    } else {
      // Handle the scenario when local storage is not available
      throw Exception("local storage is disabled");
    }
  }

  Future<List<Issue>> getTempoWorklogsIssues() async {
    try {
      var response = await _fetchIssuesFromTempoTimesheets();
      var issuesList = _parseIssuesFromResponse(response);

      return issuesList;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<dynamic> _fetchIssuesFromTempoTimesheets() async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';

    Completer<dynamic> completer = Completer();

    Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse(
            '${_apiUrl}rest/tempo-timesheets/1/tempo-worklogs?jql=worklogAuthor%20%3D%20currentUser()&period=$_tempoWorklogsPeriod&periodView=DATES&paginate=false'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          completer.complete(jsonDecode(response.body));
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  List<Issue> _parseIssuesFromResponse(Map<String, dynamic> response) {
    List<Issue> issuesList = [];
    Map<String, dynamic> transformedData = transformData(response);
    List<dynamic> issues = transformedData['issues'];

    for (var issueData in issues) {
      Issue issue = Issue.fromTempoMap(issueData);
      issuesList.add(issue);
    }

    return issuesList;
  }

  Map<String, dynamic> transformData(Map<String, dynamic> originalData) {
    List<Map<String, dynamic>> transformedIssues = [];
    Map<String, dynamic> issues = originalData['issues'];
    List<dynamic> worklogs = originalData['worklogs'];

    issues.forEach((issueId, issueData) {
      // Add issue_id to issue data
      Map<String, dynamic> transformedIssue = Map.from(issueData)..addAll({'issue_id': issueId});

      // Filter worklogs for this issue and add them to the issue data
      List<dynamic> issueWorklogs = worklogs.where((worklog) => worklog['issueId'].toString() == issueId).toList();
      transformedIssue['worklogs'] = issueWorklogs;

      transformedIssues.add(transformedIssue);
    });

    return {'issues': transformedIssues};
  }
}
