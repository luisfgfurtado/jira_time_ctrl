import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:jira_time_ctrl/models/custom_attribute.dart';

class Issue {
  String expand;
  String id;
  String self;
  String key;
  Fields fields;

  static String getFormattedWorklogTime(int totalMinutes) {
    if (totalMinutes == 0) {
      return '';
    } else if (totalMinutes < 60) {
      // Less than an hour: display in minutes
      return '$totalMinutes\u00A0min';
    } else if (totalMinutes < 1440) {
      // 1440 minutes in a day
      // Less than a day: display in hours:minutes
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      if (minutes > 0) {
        return '${hours}h$minutes';
      } else {
        return '${hours}h';
      }
    } else {
      // More than a day: display in days, hours, and minutes
      int days = totalMinutes ~/ 1440;
      int hours = (totalMinutes % 1440) ~/ 60;
      int minutes = totalMinutes % 60;
      return '${days}d${hours}h$minutes';
    }
  }

  static DateTime removeTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Map<String, int> getWorklogMinutesByWeekday(DateTime weekStart) {
    Map<String, int> worklogMinutesByDay = {
      'Monday': 0,
      'Tuesday': 0,
      'Wednesday': 0,
      'Thursday': 0,
      'Friday': 0,
      'Saturday': 0,
      'Sunday': 0,
    };

    // Remove time from weekStart and weekEnd
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    DateTime weekEnd = weekStart.add(const Duration(days: 6));

    for (WorklogEntry worklog in fields.worklog.worklogs) {
      // Check if the worklog date is within the specified week
      if (worklog.started.isAfter(weekStart.subtract(const Duration(days: 1))) && worklog.started.isBefore(weekEnd.add(const Duration(days: 1)))) {
        String weekday = DateFormat('EEEE').format(worklog.started);
        int minutes = (worklog.timeSpentSeconds / 60).round();

        if (worklogMinutesByDay.containsKey(weekday)) {
          worklogMinutesByDay[weekday] = (worklogMinutesByDay[weekday] ?? 0) + minutes;
        }
      }
    }

    return worklogMinutesByDay;
  }

  int getTotalMinutes() {
    return fields.worklog.worklogs.fold(0, (total, worklog) {
      return total + (worklog.timeSpentSeconds / 60).round();
    });
  }

  int getTotalWorklogHours() {
    int totalSeconds = fields.worklog.worklogs.fold(0, (total, worklog) {
      return total + (worklog.timeSpentSeconds);
    });
    return (totalSeconds / 3600).floor(); // Convert seconds to hours
  }

  Issue({
    required this.expand,
    required this.id,
    required this.self,
    required this.key,
    required this.fields,
  });

  Map<String, dynamic> toMap() {
    return {
      'expand': expand,
      'id': id,
      'self': self,
      'key': key,
      'fields': fields.toMap(),
    };
  }

  factory Issue.fromMap(Map<String, dynamic> map, [String currentAPIUserKey = '']) {
    return Issue(
      expand: map['expand'],
      id: map['id'],
      self: map['self'],
      key: map['key'],
      fields: Fields.fromMap(map['fields'], currentAPIUserKey),
    );
  }

  factory Issue.fromTempoMap(Map<String, dynamic> map) {
    return Issue(
      expand: 'tempo-timesheets',
      id: map['issue_id'],
      self: map['href'],
      key: map['issue_key'],
      fields: Fields.fromTempoMap(map),
    );
  }

  String toJson() => json.encode(toMap());

  factory Issue.fromJson(String source) => Issue.fromMap(json.decode(source));
}

class Fields {
  String summary;
  String projectKey;
  Worklog worklog;
  Assignee assignee;
  Status status;

  Fields({
    required this.summary,
    required this.projectKey,
    required this.worklog,
    required this.assignee,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'projectId': projectKey,
      'worklog': worklog.toMap(),
      'assignee': assignee.toMap(),
      'status': status.toMap(),
    };
  }

  factory Fields.fromMap(Map<String, dynamic> map, [String currentAPIUserKey = '']) {
    return Fields(
      summary: map['summary'],
      projectKey: map['project']['key'],
      //disable load worklogs from Jira API
      worklog: Worklog(worklogs: []), // Worklog.fromMap(map['worklog']),
      assignee: map['assignee'] != null ? Assignee.fromMap(map['assignee'], currentAPIUserKey) : Assignee(me: false),
      status: Status.fromMap(map['status']),
    );
  }

  factory Fields.fromTempoMap(Map<String, dynamic> map) {
    return Fields(
      summary: map['issue_summary'],
      projectKey: map['projectKey'],
      worklog: Worklog.fromTempoMap(map),
      assignee: Assignee.fromTempoMap(), //assign to current user
      status: Status.fromTempoMap(map),
    );
  }
}

class Worklog {
  List<WorklogEntry> worklogs;

  Worklog({
    required this.worklogs,
  });

  Map<String, dynamic> toMap() {
    return {
      'worklogs': worklogs,
    };
  }

  factory Worklog.fromMap(Map<String, dynamic> map) {
    return Worklog(
      worklogs: (map['worklogs'] as List).map((worklog) => WorklogEntry.fromMap(worklog)).toList(),
      //List<dynamic>.from(map['worklogs']),
    );
  }

  factory Worklog.fromTempoMap(Map<String, dynamic> map) {
    return Worklog(
      worklogs: (map['worklogs'] as List).map((worklog) => WorklogEntry.fromTempoMap(worklog)).toList(),
    );
  }
}

class WorklogEntry {
  String self;
  int id;
  String comment;
  DateTime started;
  String timeSpent;
  int timeSpentSeconds;
  String issueId;
  Author? author;
  Author? updateAuthor;
  List<CustomAttributeValue>? customAttributeValues;

  WorklogEntry({
    required this.self,
    required this.id,
    required this.comment,
    required this.started,
    required this.timeSpent,
    required this.timeSpentSeconds,
    required this.issueId,
    required this.author,
    required this.updateAuthor,
  });

  Map<String, dynamic> toMap() {
    return {
      'self': self,
      'id': id,
      'comment': comment,
      'started': started,
      'timeSpent': timeSpent,
      'timeSpentSeconds': timeSpentSeconds,
      'issueId': issueId,
      'author': author,
      'updateAuthor': updateAuthor,
      'customAttributeValues': customAttributeValues,
    };
  }

  factory WorklogEntry.fromMap(Map<String, dynamic> map) {
    return WorklogEntry(
      self: map['self'],
      id: int.parse(map['id']),
      comment: map['comment'] ?? '',
      started: DateTime.parse(map['started']),
      timeSpent: map['timeSpent'],
      timeSpentSeconds: map['timeSpentSeconds'],
      issueId: map['issueId'],
      author: Author.fromMap(map['author']),
      updateAuthor: Author.fromMap(map['updateAuthor']),
    );
  }
  factory WorklogEntry.fromTempoMap(Map<String, dynamic> map) {
    return WorklogEntry(
      self: '/rest/api/2/issue/${map['issueId']}/worklog/${map['id']}',
      id: map['id'],
      comment: map['comment'] ?? '',
      started: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      timeSpent: map['timeSpentFormatted'],
      timeSpentSeconds: map['timeSpent'],
      issueId: map['issueId'].toString(),
      author: Author.fromTempoMap(map['userKey']),
      updateAuthor: Author.fromTempoMap(map['updateUserKey']),
    );
  }
}

class Status {
  String self;
  String description;
  String iconUrl;
  String name;
  String id;
  StatusCategory statusCategory;

  Status({
    required this.self,
    required this.description,
    required this.iconUrl,
    required this.name,
    required this.id,
    required this.statusCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'self': self,
      'description': description,
      'iconUrl': iconUrl,
      'name': name,
      'id': id,
      'statusCategory': statusCategory.toMap(),
    };
  }

  factory Status.fromMap(Map<String, dynamic> map) {
    return Status(
      self: map['self'],
      description: map['description'],
      iconUrl: map['iconUrl'],
      name: map['name'],
      id: map['id'],
      statusCategory: StatusCategory.fromMap(map['statusCategory']),
    );
  }

  factory Status.fromTempoMap(Map<String, dynamic> map) {
    return Status(
      self: '',
      description: '',
      iconUrl: '',
      name: '',
      id: '',
      statusCategory: StatusCategory.fromTempoMap(map),
    );
  }
}

class StatusCategory {
  String self;
  int id;
  String key;
  String colorName;
  String name;

  StatusCategory({
    required this.self,
    required this.id,
    required this.key,
    required this.colorName,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'self': self,
      'id': id,
      'key': key,
      'colorName': colorName,
      'name': name,
    };
  }

  factory StatusCategory.fromMap(Map<String, dynamic> map) {
    return StatusCategory(
      self: map['self'],
      id: map['id'],
      key: map['key'],
      colorName: map['colorName'],
      name: map['name'],
    );
  }
  factory StatusCategory.fromTempoMap(Map<String, dynamic> map) {
    return StatusCategory(
      self: '',
      id: 0,
      key: '',
      colorName: '',
      name: '',
    );
  }
}

class Assignee {
  bool me;
  String self;
  String name;
  String key;
  String emailAddress;
  String displayName;
  bool active;

  Assignee({
    required this.me,
    this.self = '',
    this.name = '',
    this.key = '',
    this.emailAddress = '',
    this.displayName = '',
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'me': me,
      'self': self,
      'name': name,
      'key': key,
      'emailAddress': emailAddress,
      'displayName': displayName,
      'active': active,
    };
  }

  factory Assignee.fromMap(Map<String, dynamic> map, [String currentAPIUserKey = '']) {
    return Assignee(
      me: map['key'] == currentAPIUserKey,
      self: map['self'],
      name: map['name'],
      key: map['key'],
      emailAddress: map['emailAddress'],
      displayName: map['displayName'],
      active: map['active'],
    );
  }
  factory Assignee.fromTempoMap() {
    return Assignee(
      me: false,
    );
  }
}

class Author {
  String self;
  String name;
  String key;
  String emailAddress;
  String displayName;

  Author({
    required this.self,
    required this.name,
    required this.key,
    required this.emailAddress,
    required this.displayName,
  });

  Map<String, dynamic> toMap() {
    return {
      'self': self,
      'name': name,
      'key': key,
      'emailAddress': emailAddress,
      'displayName': displayName,
    };
  }

  factory Author.fromMap(Map<String, dynamic> map) {
    return Author(
      self: map['self'],
      name: map['name'],
      key: map['key'],
      emailAddress: map['emailAddress'],
      displayName: map['displayName'],
    );
  }
  factory Author.fromTempoMap(String userKey) {
    return Author(
      self: '',
      name: '',
      key: userKey,
      emailAddress: '',
      displayName: '',
    );
  }
}
