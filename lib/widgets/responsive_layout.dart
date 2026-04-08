import 'package:flutter/material.dart';

/// Side-by-side layout for calculators: inputs left + result right on wide screens,
/// vertical stack on narrow screens.
class CalculatorLayout extends StatelessWidget {
  final Widget inputArea;
  final Widget resultArea;
  final double breakpoint;
  final double resultWidth;

  const CalculatorLayout({
    required this.inputArea,
    required this.resultArea,
    this.breakpoint = 600,
    this.resultWidth = 300,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > breakpoint;
        return wide
            ? Row(
                children: [
                  Expanded(child: inputArea),
                  SizedBox(width: resultWidth, child: resultArea),
                ],
              )
            : Column(
                children: [
                  Expanded(child: inputArea),
                  resultArea,
                ],
              );
      },
    );
  }
}

/// Masonry column layout for card lists: single column ListView on narrow screens,
/// multi-column masonry on wide screens.
class MasonryList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T item) itemBuilder;
  final EdgeInsetsGeometry padding;

  const MasonryList({
    required this.items,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;
        if (cols == 1) {
          return ListView.builder(
            padding: padding,
            itemCount: items.length,
            itemBuilder: (_, i) => itemBuilder(items[i]),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = c; i < items.length; i += cols)
                        itemBuilder(items[i]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
