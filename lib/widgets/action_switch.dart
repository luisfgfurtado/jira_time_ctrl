import 'package:flutter/material.dart';

class ActionSwitch extends StatelessWidget {
  const ActionSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Function(bool p1) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(scale: 0.7, child: Switch(value: value, onChanged: onChanged)),
        Text(label),
      ],
    );
  }
}
