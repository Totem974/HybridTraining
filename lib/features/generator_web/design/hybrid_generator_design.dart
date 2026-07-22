import 'package:flutter/material.dart';

abstract final class HybridGeneratorTokens {
  static const background = Color(0xFF181818);
  static const surface = Color(0xFF323232);
  static const surfaceMuted = Color(0xFF727272);
  static const accent = Color(0xFF2C9EFF);
  static const text = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFFBDBDBD);

  static const contentMaxWidth = 900.0;
  static const breakpoint = 771.0;
  static const radius = 18.0;
  static const gap = 24.0;
  static const compactGap = 12.0;
  static const pagePadding = 24.0;
  static const mobilePadding = 16.0;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: surfaceMuted),
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme.copyWith(
        primary: accent,
        surface: surface,
        onSurface: text,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background.withValues(alpha: 0.36),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      dividerColor: surfaceMuted.withValues(alpha: 0.55),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

enum HybridGeneratorPage { cycle, forever }

class HybridGeneratorShell extends StatelessWidget {
  const HybridGeneratorShell({
    required this.page,
    required this.title,
    required this.child,
    this.onNavigate,
    super.key,
  });

  final HybridGeneratorPage page;
  final String title;
  final Widget child;
  final ValueChanged<HybridGeneratorPage>? onNavigate;

  @override
  Widget build(BuildContext context) => Theme(
    data: HybridGeneratorTokens.theme(),
    child: Scaffold(
      key: const Key('hybrid-generator-shell'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.sizeOf(context).width <
                    HybridGeneratorTokens.breakpoint
                ? HybridGeneratorTokens.mobilePadding
                : HybridGeneratorTokens.pagePadding,
            vertical: HybridGeneratorTokens.pagePadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: HybridGeneratorTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HybridGeneratorHeader(
                    page: page,
                    title: title,
                    onNavigate: onNavigate,
                  ),
                  const SizedBox(height: HybridGeneratorTokens.gap),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HybridGeneratorHeader extends StatelessWidget {
  const HybridGeneratorHeader({
    required this.page,
    required this.title,
    this.onNavigate,
    super.key,
  });

  final HybridGeneratorPage page;
  final String title;
  final ValueChanged<HybridGeneratorPage>? onNavigate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final heading = Text(
        title,
        key: const Key('hybrid-generator-title'),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      );
      final toggle = SegmentedButton<HybridGeneratorPage>(
        key: const Key('hybrid-generator-page-toggle'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: HybridGeneratorPage.cycle, label: Text('Cycle')),
          ButtonSegment(
            value: HybridGeneratorPage.forever,
            label: Text('Macrocycle'),
          ),
        ],
        selected: {page},
        onSelectionChanged: (selection) {
          final destination = selection.single;
          if (destination == page) return;
          if (onNavigate != null) {
            onNavigate!(destination);
          } else {
            Navigator.of(context).pushReplacementNamed(
              destination == HybridGeneratorPage.cycle ? '/cycle' : '/forever',
            );
          }
        },
      );
      return Semantics(
        container: true,
        header: true,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: HybridGeneratorTokens.compactGap),
                  toggle,
                ],
              )
            : Row(
                children: [
                  Expanded(child: heading),
                  toggle,
                ],
              ),
      );
    },
  );
}

class HybridGeneratorGrid extends StatelessWidget {
  const HybridGeneratorGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= HybridGeneratorTokens.breakpoint;
      if (!columns) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _separated(children),
        );
      }
      return Wrap(
        spacing: HybridGeneratorTokens.gap,
        runSpacing: HybridGeneratorTokens.gap,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - HybridGeneratorTokens.gap) / 2,
              child: child,
            ),
        ],
      );
    },
  );

  List<Widget> _separated(List<Widget> items) => [
    for (var index = 0; index < items.length; index++) ...[
      if (index > 0) const SizedBox(height: HybridGeneratorTokens.gap),
      items[index],
    ],
  ];
}

class HybridGeneratorCard extends StatelessWidget {
  const HybridGeneratorCard({
    required this.title,
    required this.child,
    this.collapsible = false,
    this.initiallyExpanded = true,
    super.key,
  });

  final String title;
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (collapsible) {
      return Card(
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: _CardTitle(title),
          children: [Align(alignment: Alignment.topLeft, child: child)],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: _CardTitle(title, prominent: true),
        ),
        Card(
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.value, {this.prominent = false});
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Text(
    value.toUpperCase(),
    style:
        (prominent
                ? Theme.of(context).textTheme.headlineSmall
                : Theme.of(context).textTheme.titleMedium)
            ?.copyWith(
              color: HybridGeneratorTokens.text,
              fontWeight: FontWeight.w800,
              letterSpacing: prominent ? 1.1 : 0.8,
            ),
  );
}
