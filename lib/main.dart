import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/env.dart';
import 'data/api_client.dart';
import 'data/api_repository.dart';
import 'data/repository.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/ready_screen.dart';
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
  final CondevueltaRepository repository =
      Env.useMockData ? MockRepository() : ApiRepository(ApiClient(baseUrl: Env.apiBaseUrl));
  final state = AppState(repository);
  // Not awaited: the tutorial shows while the stored session is checked.
  state.restoreSession();
  runApp(CondevueltaApp(state: state));
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
          AppStage.ready => const ReadyScreen(),
          AppStage.home => const HomeShell(),
        },
      ),
    );
  }
}
