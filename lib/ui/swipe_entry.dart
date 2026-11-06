import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'motion.dart';

class SwipeEntry extends StatefulWidget {
  const SwipeEntry({
    super.key,
    required this.id,
    required this.openId,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });
  final String id;
  final ValueNotifier<String?> openId;
  final VoidCallback onEdit, onDelete;
  final Widget child;
  @override
  State<SwipeEntry> createState() => _SwipeEntryState();
}

class _SwipeEntryState extends State<SwipeEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: PuppyMotion.press,
  );
  bool dragging = false;
  static const extent = 160.0;
  @override
  void initState() {
    super.initState();
    widget.openId.addListener(sync);
  }

  void sync() {
    if (!mounted || dragging && widget.openId.value == widget.id) return;
    final target = widget.openId.value == widget.id ? 1.0 : 0.0;
    if (PuppyMotion.reduced(context) || !TickerMode.valuesOf(context).enabled) {
      controller.value = target;
    } else {
      controller.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  void close() {
    widget.openId.value = null;
    sync();
  }

  void open() {
    widget.openId.value = widget.id;
    sync();
  }

  @override
  void dispose() {
    widget.openId.removeListener(sync);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      const CustomSemanticsAction(label: '编辑账目'): widget.onEdit,
      const CustomSemanticsAction(label: '删除账目，可撤销'): widget.onDelete,
    },
    child: ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: extent,
                  child: IgnorePointer(
                    ignoring: controller.value < .95,
                    child: ExcludeSemantics(
                      excluding: controller.value < .95,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _Action(
                              label: '编辑',
                              color: const Color(0xFFE8EEDC),
                              icon: Icons.edit_outlined,
                              key: ValueKey('edit-${widget.id}'),
                              onTap: () {
                                close();
                                widget.onEdit();
                              },
                            ),
                          ),
                          Expanded(
                            child: _Action(
                              label: '删除',
                              color: const Color(0xFFFFDCD4),
                              icon: Icons.delete_outline_rounded,
                              key: ValueKey('delete-${widget.id}'),
                              onTap: () {
                                close();
                                widget.onDelete();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-extent * controller.value, 0),
              child: GestureDetector(
                key: ValueKey('swipe-${widget.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (controller.value > .05) {
                    close();
                  } else {
                    widget.onEdit();
                  }
                },
                onLongPress: open,
                onHorizontalDragStart: (_) {
                  dragging = true;
                  controller.stop();
                  widget.openId.value = widget.id;
                },
                onHorizontalDragUpdate: (d) => controller.value =
                    (controller.value - d.delta.dx / extent).clamp(0, 1),
                onHorizontalDragEnd: (d) {
                  dragging = false;
                  final v = d.primaryVelocity ?? 0;
                  if (v < -350 || v <= 350 && controller.value > .4) {
                    open();
                  } else {
                    close();
                  }
                },
                onHorizontalDragCancel: () {
                  dragging = false;
                  sync();
                },
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressFeedback(
    child: Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
