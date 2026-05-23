import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/fitness_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;
  bool _testingNotif = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await context.read<FitnessProvider>().exportAllData();
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'K Fitness Backup',
        text: 'Your K Fitness data backup — save this file safely.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFFF453A)),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select K Fitness backup',
      );
      if (result != null && result.files.single.path != null) {
        final ok = await context.read<FitnessProvider>()
            .importAllData(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? '✅ Data restored successfully!'
                : '❌ Import failed — invalid backup file'),
            backgroundColor: ok ? const Color(0xFF30D158) : const Color(0xFFFF453A),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: const Color(0xFFFF453A)),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _testNotification() async {
    setState(() => _testingNotif = true);
    final ok = await NotificationService().sendTestNotification();
    if (mounted) {
      setState(() => _testingNotif = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '✅ Test notification sent! Check your status bar.'
            : '❌ Failed — check notification permissions in Settings'),
        backgroundColor: ok ? const Color(0xFF30D158) : const Color(0xFFFF453A),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  void _editName(FitnessProvider p) {
    final ctrl = TextEditingController(text: p.userName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Your Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Karthik'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30D158), foregroundColor: Colors.black),
            onPressed: () {
              p.saveUserName(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── PROFILE ──────────────────────────────────────────────
          _Header('Profile'),
          _Tile(
            icon: Icons.person_outline,
            title: 'Name',
            subtitle: p.userName,
            onTap: () => _editName(p),
          ),
          _Tile(
            icon: Icons.height,
            title: 'Height',
            subtitle: '${p.heightCm.round()} cm  (5.3 ft — constant)',
            onTap: null,
          ),
          const SizedBox(height: 20),

          // ── NOTIFICATIONS ─────────────────────────────────────────
          _Header('Notifications'),
          _Tile(
            icon: Icons.notifications_outlined,
            title: 'Test Notification',
            subtitle: 'Tap to fire a test notification right now',
            trailing: _testingNotif
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined, color: Color(0xFF30D158), size: 20),
            onTap: _testingNotif ? null : _testNotification,
          ),
          // Water reminder interval dropdown
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.water_drop_outlined, color: Color(0xFF30D158)),
              title: const Text('Water Reminder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Daytime only (8 AM – 9 PM)', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
              trailing: DropdownButton<int>(
                value: p.waterReminderIntervalHours,
                dropdownColor: const Color(0xFF2C2C2E),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Every 1h', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 2, child: Text('Every 2h', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 3, child: Text('Every 3h', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await p.setWaterReminderInterval(v);
                  await NotificationService().scheduleWaterReminders(intervalHours: v);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Water reminders updated to every ${v}h')));
                  }
                },
              ),
            ),
          ),
          // Walk reminder interval dropdown
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.directions_walk_outlined, color: Color(0xFF30D158)),
              title: const Text('Walk Reminder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Get up and move reminder (9 AM – 8 PM)', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
              trailing: DropdownButton<int>(
                value: p.walkReminderIntervalHours,
                dropdownColor: const Color(0xFF2C2C2E),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Every 1h', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 2, child: Text('Every 2h', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 3, child: Text('Every 3h', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 4, child: Text('Every 4h', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await p.setWalkReminderInterval(v);
                  await NotificationService().scheduleWalkReminders(intervalHours: v);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Walk reminders updated to every ${v}h')));
                  }
                },
              ),
            ),
          ),
          _Tile(
            icon: Icons.checklist_rounded,
            title: '10 PM Daily Checklist',
            subtitle: 'Reminds you to fill in anything not logged',
            trailing: const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 18),
            onTap: null,
          ),
          const SizedBox(height: 20),

          // ── GOALS ─────────────────────────────────────────────────
          _Header('Goals'),
          _Tile(
            icon: Icons.flag_outlined,
            title: 'Daily Calorie Goal',
            subtitle: '1700 kcal (fat loss target)',
            onTap: null,
          ),
          _Tile(
            icon: Icons.fitness_center_outlined,
            title: 'Daily Protein Goal',
            subtitle: '100g protein',
            onTap: null,
          ),
          _Tile(
            icon: Icons.directions_walk_outlined,
            title: 'Daily Step Goal',
            subtitle: '8,000 steps',
            onTap: null,
          ),
          _Tile(
            icon: Icons.water_drop_outlined,
            title: 'Daily Water Goal',
            subtitle: '2,500 ml',
            onTap: null,
          ),
          const SizedBox(height: 20),

          // ── DATA ──────────────────────────────────────────────────
          _Header('Data & Backup'),
          _Tile(
            icon: Icons.upload_rounded,
            title: 'Export Data',
            subtitle: 'Share your backup as a JSON file',
            trailing: _exporting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined, color: Color(0xFF30D158), size: 20),
            onTap: _exporting ? null : _export,
          ),
          _Tile(
            icon: Icons.download_rounded,
            title: 'Import Data',
            subtitle: 'Restore from a backup JSON file',
            trailing: _importing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined, color: Color(0xFF30D158), size: 20),
            onTap: _importing ? null : _import,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF30D158).withOpacity(0.3)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('💡 Safe update process',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 6),
              Text(
                'Since v1.3.0+4, this APK uses a permanent signing key. '
                'Simply install the new APK over the existing one — '
                'Android will update in place and all your data stays intact. '
                'No need to uninstall first.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── ABOUT ─────────────────────────────────────────────────
          _Header('About'),
          _Tile(
            icon: Icons.info_outline,
            title: 'K Fitness',
            subtitle: 'Version 1.3.0 — Personal fitness tracker',
            onTap: null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF8E8E93), fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 0.8)),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF30D158)),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right, color: Color(0xFF8E8E93))
          : null),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
