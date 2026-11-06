import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'shapes.dart';
import 'widgets.dart';

/// One greeting per app launch. It wraps the Navigator, so route pushes and
/// theme rebuilds do not restart it. No timer or looping animation is retained.
class StartupWelcome extends StatefulWidget {
  const StartupWelcome({super.key, required this.child});
  final Widget child;
  @override
  State<StartupWelcome> createState() => _StartupWelcomeState();
}

class _StartupWelcomeState extends State<StartupWelcome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final animation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) finish();
      });
  bool started = false, finished = false;
  bool imagesWarmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!imagesWarmed) {
      imagesWarmed = true;
      for (final key in ['lemon', 'peach', 'sage']) {
        precacheImage(AssetImage(puppyArtworkAsset(key)), context);
      }
      for (final portrait in [
        PuppyAvatar.goldenPortrait,
        PuppyAvatar.whitePortrait,
      ]) {
        precacheImage(portrait, context);
      }
    }
    if (PuppyMotion.reduced(context)) {
      animation.stop();
      finished = true;
    } else if (!started && !finished) {
      started = true;
      animation.forward();
    }
  }

  void finish() {
    if (!mounted || finished) return;
    animation.stop();
    setState(() => finished = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      TickerMode(
        enabled: finished,
        child: ExcludeSemantics(
          excluding: !finished,
          child: IgnorePointer(ignoring: !finished, child: widget.child),
        ),
      ),
      if (!finished)
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final arrival = Curves.easeOutCubic.transform(
              (t / .24).clamp(0, 1),
            );
            final opacity =
                1 - Curves.easeOut.transform(((t - .82) / .18).clamp(0, 1));
            return Opacity(
              opacity: opacity,
              child: Material(
                key: const ValueKey('startup-welcome'),
                color: cream,
                child: SafeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 54, 24, 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, 10 * (1 - arrival)),
                                  child: Opacity(
                                    opacity: arrival,
                                    child: SizedBox(
                                      width: math.min(
                                        350,
                                        constraints.maxWidth - 48,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: 512 / 350,
                                        child: Semantics(
                                          image: true,
                                          label: '白色小狗和小金毛依偎着，向你打招呼',
                                          child: PuppyGreeting(progress: t),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '小狗账本',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '嗨，今天也一起记账呀',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 8,
                        child: TextButton(
                          key: const ValueKey('skip-welcome'),
                          onPressed: finish,
                          child: const Text('跳过'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}

/// Reuse the exact approved leaning pair. Only the complete image moves;
/// no face, ears, limbs or silhouette is redrawn for the opening screen.
class PuppyGreeting extends StatelessWidget {
  const PuppyGreeting({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(math.pi * progress);
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Transform.translate(
            offset: Offset(0, -5 * bob),
            child: Transform.rotate(
              key: const ValueKey('greeting-motion'),
              angle: .018 * math.sin(2 * math.pi * progress),
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                child: Image.asset(
                  puppyArtworkAsset('sage'),
                  key: const ValueKey('greeting-dogs'),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 8,
          child: _GreetingBubble(
            text: '嗨～',
            color: butter,
            progress: ((progress - .08) / .18).clamp(0, 1),
          ),
        ),
        Positioned(
          right: 18,
          top: 0,
          child: _GreetingBubble(
            text: '你好呀',
            color: const Color(0xFFFFDED8),
            progress: ((progress - .20) / .18).clamp(0, 1),
          ),
        ),
      ],
    );
  }
}

class _GreetingBubble extends StatelessWidget {
  const _GreetingBubble({
    required this.text,
    required this.color,
    required this.progress,
  });
  final String text;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final arrival = Curves.easeOutCubic.transform(progress);
    return Opacity(
      opacity: arrival,
      child: Transform.translate(
        offset: Offset(0, 4 * (1 - arrival)),
        child: DecoratedBox(
          decoration: ledgerSurface(
            16,
            color,
            side: const BorderSide(color: ink, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
