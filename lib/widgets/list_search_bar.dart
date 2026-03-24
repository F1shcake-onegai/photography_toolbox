import 'package:flutter/material.dart';

/// Describes one filterable field with its display label and unique values.
class FilterField {
  final String category; // internal key like 'brand'
  final String label;    // display label like 'Brand' (translated)
  final List<String> values; // unique values for this field
  /// Optional display labels for values (value → display text).
  /// If null, values are shown as-is.
  final Map<String, String>? displayLabels;

  const FilterField({
    required this.category,
    required this.label,
    required this.values,
    this.displayLabels,
  });

  String displayLabel(String value) =>
      displayLabels?[value] ?? value;
}

class ListSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final List<FilterField> filterFields;
  final Set<String> activeFilters; // "category:value" keys
  final ValueChanged<String> onFilterToggled;

  const ListSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.filterFields,
    required this.activeFilters,
    required this.onFilterToggled,
  });

  @override
  State<ListSearchBar> createState() => _ListSearchBarState();
}

class _ListSearchBarState extends State<ListSearchBar> {
  /// Which field category is currently expanded (null = none).
  String? _expandedCategory;

  int _activeCountFor(FilterField field) {
    return field.values
        .where((v) => widget.activeFilters.contains('${field.category}:$v'))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: widget.onClear,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: widget.onChanged,
          ),
        ),
        // Per-field dropdown buttons row
        if (widget.filterFields.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.filterFields
                    .where((f) => f.values.isNotEmpty)
                    .map((field) {
                  final count = _activeCountFor(field);
                  final isExpanded =
                      _expandedCategory == field.category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterDropdownButton(
                      label: field.label,
                      activeCount: count,
                      isExpanded: isExpanded,
                      onTap: () {
                        setState(() {
                          _expandedCategory =
                              isExpanded ? null : field.category;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // Expanded dropdown panel for selected field
        if (_expandedCategory != null)
          Builder(builder: (context) {
            final field = widget.filterFields
                .where((f) => f.category == _expandedCategory)
                .firstOrNull;
            if (field == null || field.values.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final value in field.values)
                        _FilterCheckbox(
                          label: field.displayLabel(value),
                          selected: widget.activeFilters
                              .contains('${field.category}:$value'),
                          onTap: () => widget
                              .onFilterToggled('${field.category}:$value'),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilterDropdownButton extends StatelessWidget {
  final String label;
  final int activeCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FilterDropdownButton({
    required this.label,
    required this.activeCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasActive = activeCount > 0;

    return Material(
      color: hasActive
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasActive ? '$label ($activeCount)' : label,
                style: TextStyle(
                  fontSize: 13,
                  color: hasActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: hasActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterCheckbox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterCheckbox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
