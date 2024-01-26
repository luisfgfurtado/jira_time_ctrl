import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jira_time_ctrl/models/issue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/custom_shared_preferences.dart';

class JiraApiClient {
  late String _apiUrl;
  late String _apiKey;
  late String _boardId;
  late bool _jqlHasError;

  JiraApiClient() {
    _loadSettings(); // Call _loadSettings, but don't await here
  }

  static Future<JiraApiClient> create() async {
    var client = JiraApiClient();
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
      _boardId = prefs.getString('jiraBoardId') ?? '';
      _jqlHasError = prefs.getBool('jiraJqlHasError') ?? false;

      // debugPrint('apiUrl: $_apiUrl');
      // debugPrint('apiKey: $_apiKey');
      // debugPrint('boardId: $_boardId');
      // debugPrint('jqlHasError: $_jqlHasError');
    } else {
      // Handle the scenario when local storage is not available
      throw Exception("local storage is disabled");
    }
  }

  _setJQLHasError(bool value) async {
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('jiraJqlHasError', value);
    } else {
      throw Exception("local storage is disabled");
    }
  }

  Future<String> testConnection() async {
    var client = http.Client();
    if (_apiUrl.isEmpty) return 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) return 'Failed: Invalid Jira API key';
    if (_boardId.isEmpty) return 'Failed: Invalid board ID';

    Completer<String> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse('${_apiUrl}rest/agile/1.0/board/$_boardId/sprint'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode == 401) {
          completer.complete('Failed: Invalid or expired API key');
        } else if (response.statusCode == 404) {
          completer.complete('Failed: Invalid board ID');
        } else if (response.statusCode != 200) {
          completer.complete('Failed: (${response.statusCode})\napiUrl: $_apiUrl\napiKey: $_apiKey\nboardId: $_boardId\n\n${response.reasonPhrase}');
        } else {
          completer.complete('Connection Successful');
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<List<dynamic>> getIssuesAssignedToCurrentUser() async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';

    Completer<List<dynamic>> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse(
            '${_apiUrl}rest/api/2/search?fields=id,key,summary,project,worklog,status&jql=assignee=currentuser() and status not in (Done,Closed , resolved,Cancelled)'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode == 401) {
          completer.completeError('Failed: Invalid or expired API key');
        } else if (response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          completer.complete(jsonDecode(response.body)['issues']);
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<List<dynamic>> getIssues(String jql) async {
    if (_jqlHasError) throw Exception('JQL has an error. Unable to resubmit until JQL is fixed.');

    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';

    Completer<List<dynamic>> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse('${_apiUrl}rest/api/2/search?fields=id,key,summary,project,worklog,status&jql=$jql'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode == 401) {
          completer.completeError('Failed: Invalid or expired API key');
        } else if (response.statusCode == 400) {
          if (response.body.contains(RegExp(r'Error.*Query'))) {
            _jqlHasError = true;
            _setJQLHasError(_jqlHasError);
          }
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else if (response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          completer.complete(jsonDecode(response.body)['issues']);
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<dynamic> getIssue(String issueKey) async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';
    if (issueKey.isEmpty) throw 'Failed: Invalid Issue Key';

    Completer<dynamic> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse('${_apiUrl}rest/api/2/issue/$issueKey?fields=id,key,summary,worklog,status'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode == 401) {
          completer.completeError('Failed: Invalid or expired API key');
        } else if (response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          debugPrint(response.body);
          if (_jqlHasError) _setJQLHasError(false); //reset JQL Error status
          completer.complete(jsonDecode(response.body));
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<dynamic> getWorklogEntry(String issueKey, int worklogId) async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';
    if (issueKey.isEmpty) throw 'Failed: Invalid Issue Key';

    Completer<dynamic> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.get(
        Uri.parse('${_apiUrl}rest/api/2/issue/$issueKey/worklog/$worklogId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).then((response) {
        if (response.statusCode == 401) {
          completer.completeError('Failed: Invalid or expired API key');
        } else if (response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          debugPrint(response.body);
          if (_jqlHasError) _setJQLHasError(false); //reset JQL Error status
          completer.complete(jsonDecode(response.body));
        }
      });
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<dynamic> upInsertWorklogEntry({required WorklogEntry worklogEntry, required String adjustEstimate, required String newEstimate}) async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';

    // Format the start time
    String formattedStartTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ+0000").format(worklogEntry.started);

    dynamic headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'X-Atlassian-Token': 'no-check',
    };

    // Prepare the request body
    Map<String, dynamic> requestBody = {
      "comment": worklogEntry.comment,
      "started": formattedStartTime,
      "timeSpentSeconds": worklogEntry.timeSpentSeconds,
    };
    if (adjustEstimate != "auto") {
      requestBody["adjustEstimate"] = adjustEstimate;
      requestBody["newEstimate"] = newEstimate;
    }

    Completer<dynamic> completer = Completer();

    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      String url = worklogEntry.id == 0
          ? '${_apiUrl}rest/api/2/issue/${worklogEntry.issueId}/worklog' //add new worklog entry
          : '${_apiUrl}rest/api/2/issue/${worklogEntry.issueId}/worklog/${worklogEntry.id}'; //update worklog entry

      // Choose method based on whether it's an add or update
      var response = worklogEntry.id == 0
          ? await client.post(Uri.parse(url), headers: headers, body: jsonEncode(requestBody))
          : await client.put(Uri.parse(url), headers: headers, body: jsonEncode(requestBody));

      if (response.statusCode == 400) {
        completer.completeError('Failed: Input is invalid');
      } else if (response.statusCode == 401) {
        completer.completeError('Failed: Invalid or expired API key');
      } else if (response.statusCode == 403) {
        completer.completeError('Failed: User does not have permission to add the worklog');
      } else if (response.statusCode != 201 && response.statusCode != 200) {
        completer.completeError('Failed: (${response.statusCode})\n${response.body}');
      } else {
        completer.complete(jsonDecode(response.body));
      }
    } catch (e) {
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }

  Future<void> deleteWorklogEntry({
    required String issueKey,
    required int worklogId,
  }) async {
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';
    if (issueKey.isEmpty) throw 'Failed: Invalid Issue Key';

    Completer<void> completer = Completer();

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    try {
      await client.delete(
        Uri.parse('${_apiUrl}rest/api/2/issue/$issueKey/worklog/$worklogId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'X-Atlassian-Token': 'no-check',
        },
      ).then((response) {
        if (response.statusCode == 400) {
          completer.completeError('Failed: Input is invalid (e.g. missing required fields, invalid values, and so forth).');
        } else if (response.statusCode == 401) {
          completer.completeError('Failed: Invalid or expired API key');
        } else if (response.statusCode == 403) {
          completer.completeError('Failed: User does not have permission to delete the worklog');
        } else if (response.statusCode != 204 && response.statusCode != 201 && response.statusCode != 200) {
          completer.completeError('Failed: (${response.statusCode})\n${response.body}');
        } else {
          completer.complete();
        }
      });
    } catch (e) {
      debugPrint('deleteWorklogEntry Failed ($e)');
      completer.completeError('Error: ${e.toString()}');
    }

    return completer.future;
  }
}
