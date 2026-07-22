import 'package:flutter/material.dart';

import '../../../../generator_web/design/hybrid_generator_design.dart';

/// Presentation-only controls for configuring and generating Cycle output.
class CycleOutputBlock extends StatelessWidget {
  const CycleOutputBlock({
    required this.programTitle,
    required this.showPlating,
    required this.onProgramTitleChanged,
    required this.onShowPlatingChanged,
    required this.onGenerate,
    this.onExport,
    this.busy = false,
    this.enabled = true,
    this.isFrench = false,
    super.key,
  });

  final String programTitle;
  final bool showPlating;
  final ValueChanged<String> onProgramTitleChanged;
  final ValueChanged<bool> onShowPlatingChanged;
  final VoidCallback onGenerate;
  final VoidCallback? onExport;
  final bool busy;
  final bool enabled;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => HybridGeneratorCard(
    title: 'OUTPUT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('cycle-output-title'),
          initialValue: programTitle,
          style: const TextStyle(
            color: HybridGeneratorTokens.background,
            fontWeight: FontWeight.w600,
          ),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: isFrench ? 'Titre du programme' : 'Program title',
          ),
          onChanged: onProgramTitleChanged,
        ),
        SwitchListTile.adaptive(
          key: const Key('cycle-output-show-plating'),
          contentPadding: EdgeInsets.zero,
          title: Text(isFrench ? 'Afficher les plaques' : 'Show plating'),
          value: showPlating,
          onChanged: busy ? null : onShowPlatingChanged,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('cycle-web-generate'),
          onPressed: busy || !enabled ? null : onGenerate,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(isFrench ? 'Générer' : 'Generate'),
        ),
        if (onExport != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('cycle-web-export'),
            onPressed: busy ? null : onExport,
            icon: const Icon(Icons.download_outlined),
            label: Text(isFrench ? 'Exporter' : 'Export'),
          ),
        ],
      ],
    ),
  );
}
