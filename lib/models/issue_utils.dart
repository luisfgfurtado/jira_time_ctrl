import 'issue.dart';

List<Issue> mergeIssueLists(List<Issue> list1, List<Issue> list2) {
  Map<String, Issue> issuesMap = {for (var issue in list1) issue.id: issue};

  for (var issue in list2) {
    if (issuesMap.containsKey(issue.id)) {
      // Merge fields if necessary
      Issue existingIssue = issuesMap[issue.id]!;
      issuesMap[issue.id] = mergeIssues(existingIssue, issue);
    } else {
      issuesMap[issue.id] = issue;
    }
  }

  return issuesMap.values.toList();
}

Issue mergeIssues(Issue issue1, Issue issue2) {
  // Compare and merge each field
  String expand = issue1.expand.isEmpty ? issue2.expand : issue1.expand;
  String id = issue1.id.isEmpty ? issue2.id : issue1.id;
  String self = issue1.self.isEmpty ? issue2.self : issue1.self;
  String key = issue1.key.isEmpty ? issue2.key : issue1.key;
  Fields fields = mergeFields(issue1.fields, issue2.fields);

  return Issue(expand: expand, id: id, self: self, key: key, fields: fields);
}

Fields mergeFields(Fields fields1, Fields fields2) {
  // Compare and merge each field in Fields
  String summary = fields1.summary.isEmpty ? fields2.summary : fields1.summary;
  String projectKey = fields1.projectKey;
  Worklog worklog = mergeWorklogs(fields1.worklog, fields2.worklog);
  Status status = mergeStatus(fields1.status, fields2.status);

  return Fields(summary: summary, projectKey: projectKey, worklog: worklog, status: status);
}

Worklog mergeWorklogs(Worklog worklog1, Worklog worklog2) {
  // Map to keep track of worklogs by their ID
  Map<int, WorklogEntry> worklogsMap = {};

  // Add all worklogs from the first worklog to the map
  for (WorklogEntry worklog in worklog1.worklogs) {
    worklogsMap[worklog.id] = worklog;
  }

  // Add worklogs from the second worklog, avoiding duplicates
  for (WorklogEntry worklog in worklog2.worklogs) {
    if (!worklogsMap.containsKey(worklog.id)) {
      worklogsMap[worklog.id] = worklog;
    }
  }

  return Worklog(
    worklogs: worklogsMap.values.toList(), // Combined unique worklogs
  );
}

void replaceWorklogEntry(Worklog worklog, WorklogEntry worklogEntry) {
  // Find the index of the existing entry with the same id
  int index = worklog.worklogs.indexWhere((entry) => entry.id == worklogEntry.id);

  // If found, replace it with the new entry
  if (index != -1) {
    worklog.worklogs[index] = worklogEntry;
  }
}

void removeWorklogEntry(Worklog worklog, int entryId) {
  worklog.worklogs.removeWhere((entry) => entry.id == entryId);
}

Status mergeStatus(Status status1, Status status2) {
  String self = status1.self.isEmpty ? status2.self : status1.self;
  String description = status1.description.isEmpty ? status2.description : status1.description;
  String iconUrl = status1.iconUrl.isEmpty ? status2.iconUrl : status1.iconUrl;
  String name = status1.name.isEmpty ? status2.name : status1.name;
  String id = status1.id.isEmpty ? status2.id : status1.id;
  StatusCategory statusCategory = mergeStatusCategory(status1.statusCategory, status2.statusCategory);

  return Status(
    self: self,
    description: description,
    iconUrl: iconUrl,
    name: name,
    id: id,
    statusCategory: statusCategory,
  );
}

StatusCategory mergeStatusCategory(StatusCategory category1, StatusCategory category2) {
  String self = category1.self.isEmpty ? category2.self : category1.self;
  int id = category1.id == 0 ? category2.id : category1.id;
  String key = category1.key.isEmpty ? category2.key : category1.key;
  String colorName = category1.colorName.isEmpty ? category2.colorName : category1.colorName;
  String name = category1.name.isEmpty ? category2.name : category1.name;

  return StatusCategory(
    self: self,
    id: id,
    key: key,
    colorName: colorName,
    name: name,
  );
}
