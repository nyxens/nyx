import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/conversation.dart';

class HistoryDrawer extends StatefulWidget {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final void Function(Conversation) onSelect;
  final VoidCallback onNewChat;
  final void Function(Conversation) onDelete;
  final VoidCallback onClose;

  const HistoryDrawer({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  // ── Grouping helpers ──────────────────────────────────────────────────────

  static const _groupLabels = ['Today', 'Yesterday', 'This week', 'Earlier'];

  Map<String, List<Conversation>> _grouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<Conversation>>{
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Earlier': [],
    };

    for (final c in widget.conversations) {
      final d = DateTime(
          c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      if (!d.isBefore(today)) {
        groups['Today']!.add(c);
      } else if (!d.isBefore(yesterday)) {
        groups['Yesterday']!.add(c);
      } else if (!d.isBefore(weekAgo)) {
        groups['This week']!.add(c);
      } else {
        groups['Earlier']!.add(c);
      }
    }
    return groups;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final safeTop = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: 300,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff090B10).withOpacity(.82),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(.07),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: safeTop + 12),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Close button
                    _HeaderButton(
                      icon: Icons.menu_open_rounded,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (b) =>
                          const LinearGradient(colors: [
                        Color(0xffEAE4FF),
                        Color(0xffB388FF),
                      ]).createShader(b),
                      child: const Text(
                        'Nyx',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // New chat button
                    _HeaderButton(
                      icon: Icons.edit_outlined,
                      onTap: widget.onNewChat,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Conversation list ───────────────────────────────────────
              Expanded(
                child: widget.conversations.isEmpty
                    ? _EmptyHistory()
                    : ListView(
                        padding:
                            const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final label in _groupLabels)
                            if ((groups[label] ?? []).isNotEmpty) ...[
                              _GroupLabel(label: label),
                              for (final conv
                                  in groups[label]!)
                                _ConversationTile(
                                  conversation: conv,
                                  isActive: conv.id ==
                                      widget.activeConversationId,
                                  onTap: () {
                                    widget.onSelect(conv);
                                    widget.onClose();
                                  },
                                  onDelete: () =>
                                      widget.onDelete(conv),
                                ),
                            ],
                        ],
                      ),
              ),

              // ── Footer ─────────────────────────────────────────────────
              _DrawerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 20, color: Colors.white60),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onLongPress: () => _showDeleteDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Give the active tile a beautiful soft purple glow
            color: widget.isActive
                ? const Color(0xff8D6CFF).withOpacity(.12)
                : _hovering
                    ? Colors.white.withOpacity(.04)
                    : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xff8D6CFF).withOpacity(.25)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: widget.isActive
                          ? const Color(0xffB388FF)
                          : Colors.white30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isActive ? Colors.white : Colors.white70,
                          fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_hovering || widget.isActive)
                      GestureDetector(
                        onTap: () => _showDeleteDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showDeleteDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A1B22).withOpacity(0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Animated Icon Container ──
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 146, 16, 233).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(255, 146, 16, 233).withOpacity(0.2),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.delete_sweep_rounded,
                              color: const Color.fromARGB(255, 146, 16, 233),
                              size: 28,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        const Text(
                          'Delete conversation?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        const Text(
                          'This action cannot be undone. Are you sure you want to permanently remove this chat?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 28),
                        
                        // ── Action Buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: _GlassDialogButton(
                                text: 'Cancel',
                                onTap: () => Navigator.pop(context),
                                isDestructive: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassDialogButton(
                                text: 'Delete',
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onDelete();
                                },
                                isDestructive: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      
      // ── Custom Pop-in Animation ──
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 36, color: Colors.white12),
          const SizedBox(height: 12),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. Upgraded Footer Control Pill ─────────────────────────────────────────
class _DrawerFooter extends StatefulWidget {
  @override
  State<_DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<_DrawerFooter> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Row(
              children: [
                // Glowing Status Dot
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff4ADE80), // Emerald green
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff4ADE80).withOpacity(_pulseController.value * 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                
                // System Info
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nyx Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Local Inference Ready',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Placeholder Settings Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // TODO: Open settings sheet
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  const _GlassDialogButton({
    required this.text,
    required this.onTap,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDestructive ? const Color.fromARGB(255, 146, 16, 233) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: baseColor.withOpacity(0.2),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: baseColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}