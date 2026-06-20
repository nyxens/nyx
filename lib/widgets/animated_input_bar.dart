import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback send;
  final bool busy;

  const AnimatedInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.send,
    required this.busy,
  });

  @override
  State<AnimatedInputBar> createState() => _AnimatedInputBarState();
}

class _AnimatedInputBarState extends State<AnimatedInputBar>
    with SingleTickerProviderStateMixin {
  // Spinner animation for the "busy" state.
  late final AnimationController _spinController;

  // Tracks whether there is text — used to show/hide the send button.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void didUpdateWidget(AnimatedInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start / stop the spinner based on busy state.
    if (widget.busy && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.busy && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(.035),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconButton(
                    icon: Icons.add,
                    onTap: widget.busy ? null : () {},
                  ),

                  const SizedBox(width: 4),

                  // ── Text field ──────────────────────────────────────────
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      readOnly: widget.busy,
                      minLines: 1,
                      maxLines: 5,
                      cursorColor: Colors.white70,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 16, height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Ask anything',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),

                  // ── Mic / hidden placeholder ───────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: (widget.busy || _hasText)
                        ? const SizedBox(key: ValueKey('mic-hidden'), width: 44, height: 44)
                        : _iconButton(
                            key: const ValueKey('mic'),
                            icon: Icons.mic_none_rounded,
                            onTap: () {},
                          ),
                  ),

                  const SizedBox(width: 4),

                  // ── Send / busy button ─────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: widget.busy ? 40 : 44,
                    height: widget.busy ? 40 : 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.busy ? Colors.transparent : Colors.white,
                      border: widget.busy
                          ? Border.all(
                              color: const Color(0xff8D6CFF),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.busy
                            ? null
                            : () {
                                widget.focusNode.unfocus();
                                widget.send();
                              },
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: widget.busy
                                ? _SpinningIcon(
                                    key: const ValueKey('busy'),
                                    controller: _spinController,
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    key: ValueKey('send'),
                                    color: Colors.black,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    Key? key,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      key: key,
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 22, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ── Spinning icon extracted so its AnimationController lives outside ─────────
class _SpinningIcon extends StatelessWidget {
  final AnimationController controller;

  const _SpinningIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Transform.rotate(
        angle: controller.value * 2 * math.pi,
        child: const Icon(
          Icons.circle_outlined,
          size: 18,
          color: Color(0xffB388FF),
        ),
      ),
    );
  }
}