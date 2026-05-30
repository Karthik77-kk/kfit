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
  bool _fixingNotif = false;
  bool? _batteryOptIgnored;
  bool? _exactAlarmGranted;
  bool? _notifPermGranted; // POST_NOTIFICATIONS runtime permission (Android 13+)

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
    final result = await NotificationService().sendTestNotification();
    // Refresh permission status in parallel
    await _checkBatteryStatus();
    if (mounted) {
      setState(() => _testingNotif = false);

      String msg;
      Color bg;
      if (result == 'ok') {
        msg = '✅ Test notification sent! Check your status bar.';
        bg = const Color(0xFF30D158);
      } else if (result == 'permission_denied') {
        msg = '🚫 Notification permission denied — tap "Fix Notifications" or go to phone Settings → Apps → K Fitness → Notifications → Allow';
        bg = const Color(0xFFFF453A);
      } else {
        msg = '❌ Error: $result';
        bg = const Color(0xFFFF453A);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 6),
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
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    final ns = NotificationService();
    final ignored = await ns.isIgnoringBatteryOptimizations();
    final exactOk = await ns.canScheduleExactAlarms();
    final notifOk = await ns.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _batteryOptIgnored = ignored;
        _exactAlarmGranted = exactOk;
        _notifPermGranted = notifOk;
      });
    }
  }

  Future<void> _fixNotifications() async {
    setState(() => _fixingNotif = true);
    try {
      final p = context.read<FitnessProvider>();
      final ns = NotificationService();
      await ns.initialize();
      // Step 1: Request POST_NOTIFICATIONS runtime permission (Android 13+)
      await ns.requestPermission();
      // Step 2: Request battery optimization exclusion
      await ns.requestIgnoreBatteryOptimizations();
      // Step 3: Open exact alarm settings (Android 12+) — user must grant manually
      await ns.openExactAlarmSettings();
      // Step 4: Reschedule everything now that permissions may be granted
      await ns.rescheduleAll(
        waterInterval: p.waterReminderIntervalHours,
        walkInterval: p.walkReminderIntervalHours,
      );
      await _checkBatteryStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Permissions requested & notifications rescheduled!'),
          backgroundColor: Color(0xFF30D158),
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF453A),
        ));
      }
    } finally {
      if (mounted) setState(() => _fixingNotif = false);
    }
  }

  void _editGoal({
    required String label,
    required int current,
    required int min,
    required int max,
    required int step,
    required Future<void> Function(int) onSave,
  }) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Between $min – $max',
              helperText: 'Range: $min – $max  (step: $step)',
              helperStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30D158), foregroundColor: Colors.black),
            onPressed: () async {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null) {
                await onSave(val);
              }
              if (mounted) Navigator.pop(context);
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
            subtitle: '${p.heightCm.round()} cm (${(p.heightCm / 30.48).toStringAsFixed(1)} ft) — edit in Stats tab',
            onTap: null,
          ),
          const SizedBox(height: 20),

          // ── NOTIFICATIONS ─────────────────────────────────────────
          _Header('Notifications'),
          // Notification permission status banner (Android 13+)
          if (_notifPermGranted != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _notifPermGranted == true
                      ? const Color(0xFF30D158).withOpacity(0.4)
                      : const Color(0xFFFF453A).withOpacity(0.5),
                  width: 1.2,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _notifPermGranted == true
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: _notifPermGranted == true
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF453A),
                ),
                title: Text(
                  _notifPermGranted == true
                      ? 'Notification Permission ✓'
                      : '⚠️ Notification Permission Denied',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _notifPermGranted == true
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF453A),
                  ),
                ),
                subtitle: Text(
                  _notifPermGranted == true
                      ? 'App is allowed to send notifications'
                      : 'Tap "Fix Notifications" below, or go to phone Settings → Apps → K Fitness → Notifications → Allow all',
                  style: TextStyle(
                    color: _notifPermGranted == true
                        ? const Color(0xFF30D158).withOpacity(0.8)
                        : const Color(0xFFFF8C00),
                    fontSize: 12,
                  ),
                ),
                trailing: _notifPermGranted == true
                    ? const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 20)
                    : const Icon(Icons.open_in_new, color: Color(0xFFFF453A), size: 20),
                onTap: _notifPermGranted == true
                    ? null
                    : () => NotificationService().openNotificationSettings(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
          // Fix Notifications button
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Icon(
                _batteryOptIgnored == true
                    ? Icons.battery_saver_rounded
                    : Icons.battery_alert_rounded,
                color: _batteryOptIgnored == true
                    ? const Color(0xFF30D158)
                    : const Color(0xFFFF9F0A),
              ),
              title: const Text('Fix Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _batteryOptIgnored == true
                    ? 'Battery optimization excluded ✓ — Notifications should work'
                    : 'Tap to request battery exemption & reschedule all reminders',
                style: TextStyle(
                  color: _batteryOptIgnored == true
                      ? const Color(0xFF30D158)
                      : const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
              trailing: _fixingNotif
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _batteryOptIgnored == true
                          ? Icons.check_circle_outline
                          : Icons.build_outlined,
                      color: _batteryOptIgnored == true
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF9F0A),
                      size: 20,
                    ),
              onTap: _fixingNotif ? null : _fixNotifications,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          // Exact alarm permission status (Android 12+)
          if (_exactAlarmGranted != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(
                  _exactAlarmGranted == true
                      ? Icons.alarm_on_rounded
                      : Icons.alarm_off_rounded,
                  color: _exactAlarmGranted == true
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF453A),
                ),
                title: const Text('Exact Alarm Permission',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _exactAlarmGranted == true
                      ? 'Granted — morning & evening reminders will fire on time ✓'
                      : 'Not granted — tap "Fix Notifications" to allow exact alarms (Android 12+)',
                  style: TextStyle(
                    color: _exactAlarmGranted == true
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF453A),
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  _exactAlarmGranted == true
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: _exactAlarmGranted == true
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF453A),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          // OEM phone instructions
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF9F0A).withOpacity(0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📱 iQOO / Vivo / Samsung / Xiaomi / OnePlus users',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFFF9F0A))),
              const SizedBox(height: 8),
              const Text(
                '🔴  iQOO / Vivo — do ALL 5 steps:\n'
                '1. Tap "Fix Notifications" above (grants permission)\n'
                '2. Settings → Apps → K Fitness → Battery → Background activity → Allow\n'
                '3. Settings → Apps → K Fitness → Battery → Battery usage → No restriction\n'
                '4. Settings → Battery → App battery optimization → K Fitness → No restriction\n'
                '5. Enable Auto-start: Settings → Apps → K Fitness → Auto-start → ON\n\n'
                'Optional but recommended:\n'
                '• Open Recent Apps → long-press K Fitness → tap 🔒 Lock (prevents OS kill)\n\n'
                '🟡  Samsung / Xiaomi / OnePlus / Realme:\n'
                '1. Tap "Fix Notifications" above\n'
                '2. Settings → Apps → K Fitness → Battery → Unrestricted\n'
                '3. Allow "Exact alarms" if prompted (Android 12+)\n\n'
                'After a reboot, open K Fitness once to restore all reminders.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, height: 1.65),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => NotificationService().openNotificationSettings(),
                child: const Text(
                  'Open App Notification Settings →',
                  style: TextStyle(color: Color(0xFF30D158), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── GOALS ─────────────────────────────────────────────────
          _Header('Goals'),
          _Tile(
            icon: Icons.flag_outlined,
            title: 'Daily Calorie Goal',
            subtitle: '${p.calorieGoal} kcal — tap to change',
            onTap: () => _editGoal(
              label: 'Daily Calorie Goal (kcal)',
              current: p.calorieGoal,
              min: 800, max: 5000, step: 50,
              onSave: (v) => p.saveCalorieGoal(v),
            ),
          ),
          _Tile(
            icon: Icons.fitness_center_outlined,
            title: 'Daily Protein Goal',
            subtitle: '${p.proteinGoal}g protein — tap to change',
            onTap: () => _editGoal(
              label: 'Daily Protein Goal (g)',
              current: p.proteinGoal,
              min: 20, max: 300, step: 5,
              onSave: (v) => p.saveProteinGoal(v),
            ),
          ),
          _Tile(
            icon: Icons.directions_walk_outlined,
            title: 'Daily Step Goal',
            subtitle: '${p.stepGoal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps — tap to change',
            onTap: () => _editGoal(
              label: 'Daily Step Goal',
              current: p.stepGoal,
              min: 1000, max: 30000, step: 500,
              onSave: (v) => p.saveStepGoal(v),
            ),
          ),
          _Tile(
            icon: Icons.water_drop_outlined,
            title: 'Daily Water Goal',
            subtitle: '${p.waterGoalMl} ml — tap to change',
            onTap: () => _editGoal(
              label: 'Daily Water Goal (ml)',
              current: p.waterGoalMl,
              min: 500, max: 8000, step: 100,
              onSave: (v) => p.saveWaterGoal(v),
            ),
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
            subtitle: 'Version 1.4.1 (Build 45) — Personal fitness tracker',
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
