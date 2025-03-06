import 'dart:convert';

class CustomAttribute {
  final bool active;
  final int id;
  final String label;
  final List<String>? projectScope;
  final String type;
  final Map<String, dynamic> config;
  final String key;
  final bool required;

  CustomAttribute({
    required this.active,
    required this.id,
    required this.label,
    required this.projectScope,
    required this.type,
    required this.config,
    required this.key,
    required this.required,
  });

  factory CustomAttribute.fromJson(Map<String, dynamic> json) {
    return CustomAttribute(
      active: json['active'],
      id: json['ID'],
      label: json['label'],
      projectScope: json['projectScope'] != null ? List<String>.from(json['projectScope']) : null,
      type: json['type'],
      config: json['config'] is String ? jsonDecode(json['config']) : json['config'],
      key: json['key'],
      required: json['required'],
    );
  }
}

class CustomAttributeValue {
  String customAttributeKey;
  int customAttributeID;
  int worklogId;
  DateTime? worklogDate;
  dynamic value;
  int? id;

  CustomAttributeValue({
    required this.customAttributeKey,
    required this.customAttributeID,
    required this.worklogId,
    required this.worklogDate,
    required this.value,
    required this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'customAttributeKey': customAttributeKey,
      'customAttributeID': customAttributeID,
      'worklogId': worklogId,
      'worklogDate': worklogDate,
      'value': value,
      'id': id,
    };
  }

  factory CustomAttributeValue.fromJson(Map<String, dynamic> json) {
    return CustomAttributeValue(
      customAttributeKey: json['customAttributeKey'],
      customAttributeID: json['customAttributeID'],
      worklogId: json['worklogId'],
      worklogDate: null,
      //worklogDate: json['worklogDate'],
      value: json['value'],
      id: json['id'],
    );
  }
}
