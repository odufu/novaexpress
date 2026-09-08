import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/ecosystem_controller.dart';
import 'screens/ecosystem_screen.dart';
import 'screens/feature_presentation_screen.dart';

/// Root presentation host widget coordinating the ecosystem and feature detail views.
class PresentationRoot extends StatefulWidget {
  const PresentationRoot({super.key});

  @override
  State<PresentationRoot> createState() => _PresentationRootState();
}

class _PresentationRootState extends State<PresentationRoot> {
  late final EcosystemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EcosystemController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _controller.returnToEcosystem();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          _controller.cycleFeature(forward: true);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          _controller.cycleFeature(forward: false);
        },
        const SingleActivator(LogicalKeyboardKey.keyT): () {
          _controller.toggleThemeMode();
        },
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            final state = _controller.state;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Orbiting Ecosystem Command Screen
                EcosystemScreen(controller: _controller),

                // Presentation Screen (Fades/Slides in when selected)
                if (state.activePresentationFeature != null && !state.isTransitioning)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: FeaturePresentationScreen(
                      key: ValueKey(state.activePresentationFeature!.id),
                      feature: state.activePresentationFeature!,
                      controller: _controller,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
