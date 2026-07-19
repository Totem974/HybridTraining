import 'package:flutter/material.dart';

class Poc531LandingPage extends StatelessWidget {
  const Poc531LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('poc-531-landing'),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APP Hybrid 5/3/1 Forever',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Un laboratoire local pour explorer Original, Beyond et Forever. '
                  'Powerlifting reste une extension spécialisée.',
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ActionCard(
                      icon: Icons.route_outlined,
                      title: 'Je débute',
                      body:
                          'Parcours guidé, recommandations expliquées et configuration préremplie.',
                      label: 'Ouvrir l’onboarding',
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed('/poc/531/onboarding'),
                    ),
                    _ActionCard(
                      icon: Icons.tune,
                      title: 'Je connais mon programme',
                      body:
                          'Configurer les lifts, vérifier les compatibilités et générer le plan.',
                      label: 'Ouvrir le générateur',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/poc/531/generator'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'POC informatif : ce générateur ne constitue ni un conseil médical '
                  'ni une garantie de résultat.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 400,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(label)),
          ],
        ),
      ),
    ),
  );
}
