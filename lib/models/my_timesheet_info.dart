import 'custom_attribute.dart';

class MyTimesheetInfo {
  final DateTime? startDate;
  final DateTime? endDate;
  final double maxHoursPerDay;
  final List<String> addedIssues;
  final List<CustomAttribute> customAttributes;
  final List<CustomAttributeValue> customAttributeValues;

  MyTimesheetInfo({
    required this.startDate,
    required this.endDate,
    required this.maxHoursPerDay,
    required this.addedIssues,
    required this.customAttributes,
    required this.customAttributeValues,
  });

  factory MyTimesheetInfo.fromJson(Map<String, dynamic> json) {
    return MyTimesheetInfo(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      maxHoursPerDay: json['maxHoursPerDay'],
      addedIssues: List<String>.from(json['addedIssues']),
      customAttributes: (json['customAttributes'] as List).map((attr) => CustomAttribute.fromJson(attr)).toList(),
      customAttributeValues: _parseCustomAttributeValues(json['customAttributeValues']),
    );
  }

  static List<CustomAttributeValue> _parseCustomAttributeValues(Map<String, dynamic> json) {
    List<CustomAttributeValue> values = [];
    json.forEach((key, value) {
      value.forEach((id, worklogId) {
        worklogId.forEach((id, attributeValue) {
          values.add(CustomAttributeValue.fromJson(attributeValue));
        });
      });
    });
    return values;
  }
}
