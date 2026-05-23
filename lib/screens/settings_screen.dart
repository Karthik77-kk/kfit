import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await context.read<FitnessProvider>().exportAllData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text('Export Successful ✅'),
            content: Text(
              'Backup saved to:\n\n$path\n\nCopy this file before updating the app.',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF30D158))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the full path to your backup JSON file:',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: '/path/to/karthik_fitness_backup.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30D158), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.isNotEmpty) {
      final ok = await context.read<FitnessProvider>().importAllData(ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Data imported successfully! ✅' : 'Import failed. Check the file path.'),
            backgroundColor: ok ? const Color(0xFF30D158) : const Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile
          _SectionHeader('Profile'),
          _SettingsTile(
            icon: Icons.height,
            title: 'Height',
            subtitle: '${p.heightCm.toStringAsFixed(0)} cm (5.3 ft — fixed)',
            onTap: null,
          ),

          const SizedBox(height: 20),
          _SectionHeader('Notifications'),
          _DropdownTile(
            icon: Icons.water_drop_outlined,
            title: 'Water Reminder Interval',
            value: p.waterReminderIntervalHours,
            options: const {1: 'Every hour', 2: 'Every 2 hours', 3: 'Every 3 hours'},
            onChanged: (v) async {
              await p.setWaterReminderInterval(v);
              await NotificationService().scheduleWaterReminders(intervalHours: v);
            },
          ),
          _SettingsTile(
            icon: Icons.checklist_rounded,
            title: '10 PM Daily Checklist',
            subtitle: 'Reminds you to complete your daily log',
            trailing: const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 18),
            onTap: null,
          ),

          const SizedBox(height: 20),
          _SectionHeader('Data'),
          _SettingsTile(
            icon: Icons.upload_rounded,
            title: 'Export Data',
            subtitle: 'Save all your data to a JSON backup file',
            onTap: _exporting ? null : _export,
            trailing: _exporting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Import Data',
            subtitle: 'Restore from a JSON backup file',
            onTap: _import,
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('💡 How to update the app safely',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 8),
              Text(
                '1. Export your data (above)\n'
                '2. Copy the backup file to a safe location\n'
                '3. Install the new APK — since the version code increases, '
                'Android updates in place and your data is preserved\n'
                '4. If you ever reinstall from scratch, use Import to restore',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, height: 1.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF30D158)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Color(0xFF8E8E93))
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final Map<int, String> options;
  final void Function(int) onChanged;
  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF30D158)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: DropdownButton<int>(
          value: value,
          dropdownColor: const Color(0xFF2C2C2E),
          underline: const SizedBox(),
          items: options.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
