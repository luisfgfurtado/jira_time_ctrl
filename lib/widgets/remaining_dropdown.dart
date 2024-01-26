import 'package:flutter/material.dart';

class RemainingDropdown extends StatefulWidget {
  final Function(String) onSelectionChanged;
  const RemainingDropdown({super.key, required this.onSelectionChanged});

  @override
  _RemainingDropdown createState() => _RemainingDropdown();
}

class _RemainingDropdown extends State<RemainingDropdown> {
  String _currentSelection = 'auto';
  final Map<String, String> _options = {
    'new': 'sets the estimate to a specific value',
    'leave': 'leaves the estimate as is',
    'manual': 'specify a specific amount to increase remaining estimate by',
    'auto': 'Default option. Will automatically adjust the value based on the new timeSpent specified on the worklog'
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        DropdownButton<String>(
          value: _currentSelection,
          onChanged: (String? newValue) {
            setState(() {
              _currentSelection = newValue!;
            });
            widget.onSelectionChanged(_currentSelection); // Call the callback function
          },
          items: _options.keys.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_options[_currentSelection] ?? ''),
        ),
      ],
    );
  }
}
