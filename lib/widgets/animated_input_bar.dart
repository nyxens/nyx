import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedInputBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 28,
            sigmaY: 28,
          ),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 60,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(.035),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  _iconButton(
                    icon: Icons.add,
                    onTap: busy ? null : () {},
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: busy,
                      minLines: 1,
                      maxLines: 5,
                      cursorColor: Colors.white70,
                      textCapitalization:
                          TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: "Ask anything",
                        hintStyle: TextStyle(
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),

                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                          )
                        : _iconButton(
                            icon: Icons.mic_none_rounded,
                            onTap: () {},
                          ),
                  ),

                  const SizedBox(width: 4),

                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 260,
                    ),
                    curve: Curves.easeOutCubic,

                    width: busy ? 40 : 44,
                    height: busy ? 40 : 44,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: busy
                          ? Colors.transparent
                          : Colors.white,

                      border: busy
                          ? Border.all(
                              color: const Color(
                                0xff8D6CFF,
                              ),
                              width: 2,
                            )
                          : null,
                    ),

                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: busy
                            ? null
                            : () {
                                focusNode.unfocus();
                                send();
                              },

                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(
                              milliseconds: 220,
                            ),

                            transitionBuilder: (
                              child,
                              animation,
                            ) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },

                            child: busy
                                ? TweenAnimationBuilder<double>(
                                    key: const ValueKey(
                                      "thinking",
                                    ),
                                    tween: Tween(
                                      begin: 0,
                                      end: 1,
                                    ),
                                    duration: const Duration(
                                      seconds: 2,
                                    ),

                                    builder:
                                        (
                                          context,
                                          value,
                                          child,
                                        ) {
                                      return Transform.rotate(
                                        angle:
                                            value *
                                            6.28318,
                                        child: const Icon(
                                          Icons.circle_outlined,
                                          size: 18,
                                          color: Color(
                                            0xffB388FF,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    key: ValueKey(
                                      "send",
                                    ),
                                    color: Colors.black,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}