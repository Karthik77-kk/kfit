import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

const _kCard = Color(0xFF1C1C1E);
const _kSecond = Color(0xFF8E8E93);

/// Opens the in-app notification center as a full page.
void openNotifications(BuildContext context) {
  context.read<FitnessProvider>().markNotificationsRead();
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final insights = p.liveInsightFeed;
    final milestones = p.milestoneFeed;
    final isEmpty = insights.isEmpty && milestones.isEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (milestones.isNotEmpty)
            TextButton(
              onPressed: () => context.read<FitnessProvider>().clearNotifications(),
              child: const Text('Clear', style: TextStyle(color: _kSecond)),
            ),
        ],
      ),
      body: isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (insights.isNotEmpty) ...[
                  _SectionLabel('RIGHT NOW', subtitle: 'Live — updates as your day changes'),
                  ...insights.map((n) => _NotificationTile(n, showTime: false)),
                  const SizedBox(height: 18),
                ],
                if (milestones.isNotEmpty) ...[
                  const _SectionLabel('ACHIEVEMENTS'),
                  ...milestones.map((n) => _NotificationTile(n, showTime: true)),
                ],
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🔔', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('Nothing right now',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Live coaching tips and your milestones will appear here as you log.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kSecond, fontSize: 13, height: 1.5)),
          ]),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? subtitle;
  const _SectionLabel(this.text, {this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: const TextStyle(
                  color: _kSecond, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style: TextStyle(color: _kSecond.withOpacity(0.7), fontSize: 11)),
            ),
        ]),
      );
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final bool showTime;
  const _NotificationTile(this.n, {required this.showTime});

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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(n.emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(n.title,
                    style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              if (showTime) ...[
                const SizedBox(width: 6),
                Text(_relative(n.timestamp),
                    style: const TextStyle(color: _kSecond, fontSize: 10)),
              ],
            ]),
            const SizedBox(height: 4),
            Text(n.body,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}
