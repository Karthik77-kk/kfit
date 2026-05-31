import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/fitness_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;

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
