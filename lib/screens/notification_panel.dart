import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

const _kCard = Color(0xFF1C1C1E);
const _kSecond = Color(0xFF8E8E93);
const _kGreen = Color(0xFF30D158);

/// Opens the notification center as a slide-down panel from the top.
void showNotificationPanel(BuildContext context) {
  // Mark everything read as soon as the user opens the panel.
  context.read<FitnessProvider>().markNotificationsRead();
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1), end: Offset.zero,
          ).animate(curved),
          child: const _NotificationPanel(),
        ),
      );
    },
  );
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final items = context.watch<FitnessProvider>().appNotifications;

    final today = <AppNotification>[];
    final earlier = <AppNotification>[];
    final now = DateTime.now();
    for (final n in items) {
      final sameDay = n.timestamp.year == now.year &&
          n.timestamp.month == now.month &&
          n.timestamp.day == now.day;
      (sameDay ? today : earlier).add(n);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.fromLTRB(8, top + 6, 8, 0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: _kGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text('Notifications',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          context.read<FitnessProvider>().clearNotifications(),
                      child: const Text('Clear',
                          style: TextStyle(color: _kSecond, fontSize: 13)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _kSecond, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2C2C2E)),

            // Body
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(children: [
                  Text('🔕', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Insights, milestones and reminders will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kSecond, fontSize: 12, height: 1.4)),
                ]),
              )
            else
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  shrinkWrap: true,
                  children: [
                    if (today.isNotEmpty) ...[
                      _groupLabel('Today'),
                      ...today.map((n) => _NotificationTile(n)),
                    ],
                    if (earlier.isNotEmpty) ...[
                      _groupLabel('Earlier'),
                      ...earlier.map((n) => _NotificationTile(n)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: _kSecond, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  const _NotificationTile(this.n);

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(n.accent);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(n.emoji, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(n.title,
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(_relative(n.timestamp),
                  style: const TextStyle(color: _kSecond, fontSize: 10)),
            ]),
            const SizedBox(height: 3),
            Text(n.body,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}
