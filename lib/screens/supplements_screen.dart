import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../services/notification_service.dart';

class SupplementsScreen extends StatelessWidget {
  const SupplementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplements 💊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_add_outlined),
            tooltip: 'Set supplement reminders',
            onPressed: () async {
              await NotificationService().scheduleSupplementReminders();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('⏰ Supplement reminders set!'),
                  backgroundColor: Color(0xFF9B59B6),
                ));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Progress summary ──────────────────────────────────────────────
          _ProgressHeader(taken: p.supplements.takenCount),
          const SizedBox(height: 20),

          // ── Supplement cards ──────────────────────────────────────────────
          _SupplementCard(
            emoji: '💪',
            name: 'Whey Protein',
            brand: 'Nutrabay Gold 100% Whey',
            amount: '1 scoop (25g protein)',
            timing: 'Post-workout · or anytime',
            tip: 'Mix with 200ml water or milk. 2 scoops only if dietary protein is low.',
            color: const Color(0xFFFF6B35),
            taken: p.supplements.whey,
            onToggle: (val) => p.updateSupplement('whey', val),
          ),
          const SizedBox(height: 12),

          _SupplementCard(
            emoji: '⚡',
            name: 'Creatine Monohydrate',
            brand: 'Nutrabay Pure Micronised',
            amount: '3–5g daily',
            timing: 'Any time · Every day (incl. rest days)',
            tip: 'No loading phase needed. Can mix with whey or plain water. Take it consistently.',
            color: const Color(0xFF4ECDC4),
            taken: p.supplements.creatine,
            onToggle: (val) => p.updateSupplement('creatine', val),
          ),
          const SizedBox(height: 12),

          _SupplementCard(
            emoji: '🌿',
            name: 'Multivitamin',
            brand: 'MuscleBlaze MB-Vite',
            amount: '1 tablet daily',
            timing: 'After breakfast — always with food',
            tip: 'Covers micronutrient gaps. Not a substitute for a good diet, but great as backup.',
            color: const Color(0xFF9B59B6),
            taken: p.supplements.multivitamin,
            onToggle: (val) => p.updateSupplement('multivitamin', val),
          ),
          const SizedBox(height: 24),

          // ── Reminder tip ──────────────────────────────────────────────────
          _ReminderTip(),
          const SizedBox(height: 16),

          // ── Avoid section ─────────────────────────────────────────────────
          _AvoidSection(),
        ],
      ),
    );
  }
}

// ── Progress header ────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int taken;
  const _ProgressHeader({required this.taken});

  @override
  Widget build(BuildContext context) {
    final messages = [
      'Nothing taken yet today',
      '1 of 3 supplements done',
      '2 of 3 done — almost there!',
      '🎉 All 3 supplements taken today!',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: taken == 3
              ? [
                  const Color(0xFF27AE60).withOpacity(0.25),
                  const Color(0xFF27AE60).withOpacity(0.10),
                ]
              : [
                  const Color(0xFF9B59B6).withOpacity(0.2),
                  const Color(0xFF9B59B6).withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: taken == 3
              ? const Color(0xFF27AE60).withOpacity(0.4)
              : const Color(0xFF9B59B6).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: taken / 3,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    taken == 3
                        ? const Color(0xFF27AE60)
                        : const Color(0xFF9B59B6),
                  ),
                ),
                Text(
                  '$taken/3',
                  style: TextStyle(
                    color: taken == 3
                        ? const Color(0xFF27AE60)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages[taken],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Consistency is key — take these daily for best results.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supplement card ────────────────────────────────────────────────────────────

class _SupplementCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String brand;
  final String amount;
  final String timing;
  final String tip;
  final Color color;
  final bool taken;
  final ValueChanged<bool> onToggle;

  const _SupplementCard({
    required this.emoji,
    required this.name,
    required this.brand,
    required this.amount,
    required this.timing,
    required this.tip,
    required this.color,
    required this.taken,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: taken
            ? color.withOpacity(0.12)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: taken ? color.withOpacity(0.5) : color.withOpacity(0.2),
          width: taken ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: taken ? color : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      brand,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: taken,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: color,
                  checkColor: Colors.white,
                  side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.scale_outlined, label: amount, color: color),
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.access_time, label: timing, color: color),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }
}

// ── Reminder tip ───────────────────────────────────────────────────────────────

class _ReminderTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm, color: Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set daily reminders',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(
                  'Tap the 🔔 icon above to get reminded for multivitamin (8:30am) and creatine (10am) daily.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avoid section ──────────────────────────────────────────────────────────────

class _AvoidSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const avoid = [
      '❌ Fat burners — waste of money, side effects',
      '❌ Mass gainers — adds unwanted fat',
      '❌ BCAAs — not needed if you have whey',
      '❌ Testosterone boosters — not for your age/goal',
      '❌ Fancy creatine types (HCl, Kre-Alkalyn) — pure monohydrate is best',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚫 Supplements to avoid',
            style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...avoid.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  s,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      height: 1.3),
                ),
              )),
        ],
      ),
    );
  }
}
