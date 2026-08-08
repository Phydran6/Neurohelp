import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Neurohelp')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Neurohelp', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Flavor: ${AppConfig.instance.flavor.name}',
              style: theme.textTheme.bodyMedium,
              key: const Key('home_flavor_label'),
            ),
          ],
        ),
      ),
    );
  }
}
