import 'package:flutter/material.dart';

class FilterChips extends StatelessWidget {
  final List<String> options;
  final String? selectedOption;
  final Function(String?) onSelected;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((option) {
        final isSelected = selectedOption == option;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            onSelected(selected ? option : null);
          },
        );
      }).toList(),
    );
  }
}
