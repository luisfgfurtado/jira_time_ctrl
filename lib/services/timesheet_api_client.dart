import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jira_time_ctrl/models/my_timesheet_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/custom_shared_preferences.dart';

class TimesheetApiClient {
  late String _apiUrl;
  late String _apiKey;

  TimesheetApiClient() {
    _loadSettings(); // Call _loadSettings, but don't await here
  }

  static Future<TimesheetApiClient> create() async {
    var client = TimesheetApiClient();
    await client._loadSettings(); // Ensure settings are loaded
    return client;
  }

  Future<void> _loadSettings() async {
    debugPrint("TimesheetApiClient - _loadSettings");
    bool localStorageIsEnabled = await CustomSharedPreferences.checkIfLocalStorageIsEnabled();
    if (localStorageIsEnabled) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? storedApiUrl = prefs.getString('jiraApiUrl');
      _apiUrl = (storedApiUrl != null && !storedApiUrl.endsWith('/')) ? '$storedApiUrl/' : storedApiUrl ?? '';
      _apiKey = prefs.getString('jiraApiKey') ?? '';
    } else {
      // Handle the scenario when local storage is not available
      throw Exception("local storage is disabled");
    }
  }

  Future<MyTimesheetInfo> getMyTimesheetInfo(String startDate, String endDate) async {
    debugPrint("TimesheetApiClient - getMyTimesheetInfo");
    try {
      var response = await _fetchMyTimesheetInfo(startDate, endDate);
      var myTimesheetInfo = _parseTimesheetInfo(response);
      return myTimesheetInfo;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<dynamic> _fetchMyTimesheetInfo(String startDate, String endDate) async {
    debugPrint("TimesheetApiClient - _fetchMyTimesheetInfo");
    var client = http.Client();
    if (_apiUrl.isEmpty) throw 'Failed: Invalid Jira API URL';
    if (_apiKey.isEmpty) throw 'Failed: Invalid Jira API key';

    Completer<dynamic> completer = Completer();

    Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout error');
      }
    });

    Map<String, dynamic> requestBody = {
      "timeZone": "Europe/Warsaw",
      "reportTo": {
        "selectedPageIndex": 1,
        "owner": null,
        "pages": [
          {
            "id": null,
            "index": 1,
            "row": [],
            "column": [],
            "data": [],
            "outputType": "list",
            "days": 0,
            "dateRange": null,
            "startDate": startDate,
            "endDate": endDate,
            "includeNoTimeUser": false,
            "includeNPT": true
          }
        ]
      }
    };

    try {
      await client
          .post(Uri.parse('${_apiUrl}rest/aio-jr/1.0/timesheet/myTimesheetInfo'),
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(requestBody))
          .then((response) {
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

  MyTimesheetInfo _parseTimesheetInfo(Map<String, dynamic> response) {
    return MyTimesheetInfo.fromJson(response);
  }
}
