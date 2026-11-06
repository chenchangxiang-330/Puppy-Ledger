import 'shapes.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class PuppyMotion {
  static const press = Duration(milliseconds: 180);
  static const theme = Duration(milliseconds: 300);
  static const arrival = Duration(milliseconds: 280);
  static const dog = Duration(milliseconds: 520);
  static const bubble = Duration(milliseconds: 1500);
  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return (media?.disableAnimations ?? features.disableAnimations) ||
        (media?.accessibleNavigation ?? features.accessibleNavigation);
  }

  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;
}

/// Raw pointer feedback leaves gesture recognition to the real button/list.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  Offset? origin;
  void change(bool value) {
    if (pressed != value && mounted) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (e) {
            origin = e.position;
            change(true);
          }
        : null,
    onPointerMove: (e) {
      if (origin != null && (e.position - origin!).distance > 12) change(false);
    },
    onPointerUp: (_) => change(false),
    onPointerCancel: (_) => change(false),
    child: AnimatedScale(
      scale: pressed && widget.enabled && !PuppyMotion.reduced(context)
          ? .96
          : 1,
      duration: PuppyMotion.duration(context, PuppyMotion.press),
      curve: pressed ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

class EntryArrival extends StatefulWidget {
  const EntryArrival({super.key, required this.animate, required this.child});
  final bool animate;
  final Widget child;
  @override
  State<EntryArrival> createState() => _EntryArrivalState();
}

class _EntryArrivalState extends State<EntryArrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: PuppyMotion.arrival,
    value: 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && controller.value == 1 && !_started) start();
    if (PuppyMotion.reduced(context)) controller.value = 1;
  }

  bool _started = false;
  void start() {
    _started = true;
    if (!PuppyMotion.reduced(context)) controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant EntryArrival old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: controller.value,
      child: Transform.translate(
        offset: Offset(0, 9 * (1 - Curves.easeOut.transform(controller.value))),
        child: child,
      ),
    ),
  );
}

/// Caption has its own reserved area, so particles and text never cover amounts.
class PuppyCompanion extends StatefulWidget {
  const PuppyCompanion({
    super.key,
    required this.leading,
    required this.dog,
    required this.themeKey,
    required this.active,
    required this.celebration,
    this.successMessage = '记好啦！',
    this.successDog,
  });
  final Widget leading, dog;
  final String themeKey;
  final bool active;
  final int celebration;
  final String successMessage;
  final Widget? successDog;
  @override
  State<PuppyCompanion> createState() => _PuppyCompanionState();
}

class _PuppyCompanionState extends State<PuppyCompanion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: PuppyMotion.dog,
  );
  Timer? bubbleTimer;
  String? caption;
  DateTime? lastTap;
  bool foreground = true, celebrating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    bubbleTimer?.cancel();
    animation.stop();
    animation.value = 0;
    caption = null;
    celebrating = false;
  }

  @override
  void didUpdateWidget(covariant PuppyCompanion old) {
    super.didUpdateWidget(old);
    if (!widget.active || old.themeKey != widget.themeKey) stop();
    if (widget.active && widget.celebration != old.celebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) play(success: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground && mounted) setState(stop);
  }

  void play({bool success = false}) {
    if (!widget.active || !foreground) return;
    final now = DateTime.now();
    if (!success &&
        (animation.isAnimating ||
            (lastTap != null &&
                now.difference(lastTap!).inMilliseconds < 700))) {
      return;
    }
    lastTap = now;
    bubbleTimer?.cancel();
    celebrating = success;
    setState(
      () => caption = success
          ? widget.successMessage
          : switch (widget.themeKey) {
              'peach' => '贴贴，快乐记一笔',
              'sage' => '又是元气满满的一天',
              _ => '今天也要好好记账呀',
            },
    );
    if (!PuppyMotion.reduced(context)) {
      animation.forward(from: 0);
      if (success) unawaited(HapticFeedback.lightImpact());
    }
    bubbleTimer = Timer(PuppyMotion.bubble, () {
      if (mounted) {
        setState(() {
          caption = null;
          celebrating = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    bubbleTimer?.cancel();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PuppyMotion.reduced(context);
    final bubbleHeight = MediaQuery.textScalerOf(context).scale(12) * 2.6 + 12;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: RepaintBoundary(child: widget.leading)),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: '和小狗互动',
              child: GestureDetector(
                key: const ValueKey('home-puppy'),
                onTap: play,
                behavior: HitTestBehavior.opaque,
                child: RepaintBoundary(
                  key: const ValueKey('puppy-motion-layer'),
                  child: AnimatedBuilder(
                    animation: animation,
                    child: celebrating
                        ? (widget.successDog ?? widget.dog)
                        : widget.dog,
                    builder: (context, child) {
                      final t = reduced ? 0.0 : animation.value;
                      final wave = math.sin(math.pi * t);
                      final peach = widget.themeKey == 'peach';
                      final dy = peach
                          ? -2 * wave
                          : -(widget.themeKey == 'sage' ? 12 : 7) * wave;
                      final rotate = peach
                          ? .045 * math.sin(4 * math.pi * t) * wave
                          : .015 * math.sin(2 * math.pi * t);
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(0, dy),
                            child: Transform.rotate(
                              angle: rotate,
                              child: Transform.scale(
                                scale: 1 + .025 * wave,
                                child: child,
                              ),
                            ),
                          ),
                          if (!reduced &&
                              t > 0 &&
                              t < 1 &&
                              (peach || widget.themeKey == 'sage'))
                            for (var i = 0; i < 3; i++)
                              Positioned(
                                left: 12.0 + i * 35,
                                top: 16 - 12 * t + (i.isOdd ? 5 : 0),
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: wave.clamp(0, 1),
                                    child: Transform.scale(
                                      scale: .6 + .4 * wave,
                                      child: Icon(
                                        peach
                                            ? Icons.favorite_rounded
                                            : Icons.star_rounded,
                                        size: 12 + i * 2.0,
                                        color: peach
                                            ? const Color(0xFFEB8279)
                                            : const Color(0xFFB59132),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: bubbleHeight,
          child: Center(
            child: AnimatedSwitcher(
              duration: PuppyMotion.duration(
                context,
                const Duration(milliseconds: 140),
              ),
              child: caption == null
                  ? const SizedBox(key: ValueKey('no-bubble'))
                  : Semantics(
                      liveRegion: true,
                      child: Container(
                        key: ValueKey(caption),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: ledgerSurface(
                          12,
                          Colors.white.withValues(alpha: .9),
                          side: BorderSide(color: const Color(0xFFE5DED2)),
                        ),
                        child: Text(
                          caption!,
                          key: const ValueKey('puppy-bubble'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Restrict horizontal paging to the date header, never the account rows.
class PeriodSwipe extends StatefulWidget {
  const PeriodSwipe({super.key, required this.onMove, required this.child});
  final ValueChanged<int> onMove;
  final Widget child;
  @override
  State<PeriodSwipe> createState() => _PeriodSwipeState();
}

class _PeriodSwipeState extends State<PeriodSwipe> {
  double travel = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => travel = 0,
    onHorizontalDragUpdate: (d) => travel += d.delta.dx,
    onHorizontalDragEnd: (d) {
      final speed = d.primaryVelocity ?? 0;
      if (travel.abs() >= 42 || speed.abs() >= 450) {
        widget.onMove((speed.abs() >= 450 ? speed : travel) < 0 ? 1 : -1);
      }
      travel = 0;
    },
    onHorizontalDragCancel: () => travel = 0,
    child: widget.child,
  );
}
