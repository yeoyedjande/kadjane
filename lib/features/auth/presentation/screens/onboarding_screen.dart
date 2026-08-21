import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_logo.dart';

/// Présentation en trois écrans, affichée une seule fois.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(appSettingsProvider.notifier).markOnboardingSeen();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingPage> pages = <_OnboardingPage>[
      _OnboardingPage(
        icon: Icons.groups_2_outlined,
        title: context.l10n.onboardingTitle1,
        body: context.l10n.onboardingBody1,
      ),
      _OnboardingPage(
        icon: Icons.casino_outlined,
        title: context.l10n.onboardingTitle2,
        body: context.l10n.onboardingBody2,
      ),
      _OnboardingPage(
        icon: Icons.history_edu_outlined,
        title: context.l10n.onboardingTitle3,
        body: context.l10n.onboardingBody3,
      ),
    ];
    final bool isLast = _index == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.lg,
                KSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  const KLogo(size: 36),
                  const SizedBox(width: KSpacing.md),
                  Text(context.l10n.appName, style: context.text.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(context.l10n.commonSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (int value) => setState(() => _index = value),
                itemBuilder: (BuildContext context, int index) => pages[index],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                pages.length,
                (int index) => AnimatedContainer(
                  duration: KDurations.normal,
                  margin: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
                  height: 6,
                  width: index == _index ? 24 : 6,
                  decoration: BoxDecoration(
                    color: index == _index
                        ? context.scheme.primary
                        : context.colors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: KButton(
                label: isLast
                    ? context.l10n.commonStart
                    : context.l10n.commonNext,
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: KDurations.normal,
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 168,
            width: 168,
            decoration: BoxDecoration(
              color: context.scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 76,
              color: context.scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: KSpacing.huge),
          Text(
            title,
            style: context.text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            body,
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
