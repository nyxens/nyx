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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white30,
          letterSpacing: .6,
        ),
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
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.isActive
                ? Colors.white.withOpacity(.07)
                : _hovering
                    ? Colors.white.withOpacity(.04)
                    : Colors.transparent,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: widget.isActive
                          ? const Color(0xffB388FF)
                          : Colors.white30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isActive
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: widget.isActive
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    // Delete button on hover / active
                    if (_hovering || widget.isActive)
                      GestureDetector(
                        onTap: () => _showDeleteDialog(context),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: Colors.white24,
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
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1A1B22),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete conversation?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xffFF6B6B))),
          ),
        ],
      ),
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

class _DrawerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xff7C4DFF), Color(0xffB388FF)],
              ),
            ),
            child: const Center(
              child: Text('N',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nyx',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Local AI · Offline',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}