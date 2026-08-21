import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';

/// Coquille de l'application : barre de navigation à 5 onglets.
///
/// Chaque onglet conserve son état de navigation grâce à
/// `StatefulShellRoute.indexedStack`.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (int index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.savings_outlined),
            selectedIcon: const Icon(Icons.savings_rounded),
            label: context.l10n.navTontines,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: context.l10n.navContributions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timeline_outlined),
            selectedIcon: const Icon(Icons.timeline),
            label: context.l10n.navActivity,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
