import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/repository.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // TODO: swap MockRepository for an ApiRepository once the customer
  // endpoints exist in ../web (see AGENTS.txt, section 6).
  runApp(CondevueltaApp(state: AppState(MockRepository())));
}

class CondevueltaApp extends StatelessWidget {
  const CondevueltaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Condevuelta',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _StageSwitcher(),
      ),
    );
  }
}

/// Animates between the top-level stages (tutorial, sign-in steps, home).
class _StageSwitcher extends StatelessWidget {
  const _StageSwitcher();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final direction = state.isGoingBack ? -1.0 : 1.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(state.stage);
        final offset = Tween(
          begin: Offset(0.18 * (isIncoming ? direction : -direction), 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(state.stage),
        child: switch (state.stage) {
          AppStage.onboarding => const OnboardingScreen(),
          AppStage.email => const EmailScreen(),
          AppStage.code => const CodeScreen(),
          AppStage.name => const NameScreen(),
          AppStage.home => const HomeShell(),
        },
      ),
    );
  }
}
