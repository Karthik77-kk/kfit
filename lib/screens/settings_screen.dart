import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../app_info.dart';
import '../theme/app_tokens.dart';
import '../providers/fitness_provider.dart';
import '../services/on_device_ai_service.dart';
import 'chat_screen.dart' show openChat;

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
        // Confirm before overwriting all current data
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text('Replace all data?'),
            content: const Text(
              'This will overwrite ALL your current data with the backup. This cannot be undone.',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore', style: TextStyle(color: Color(0xFFFF453A))),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
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
          decoration: const InputDecoration(hintText: 'Enter your name'),
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
    ).then((_) => ctrl.dispose());
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
              final parsed = int.tryParse(ctrl.text.trim());
              if (parsed != null) {
                // Enforce the advertised range — an out-of-range goal (e.g. 0 or
                // 50000 kcal) would break deficit/progress maths downstream.
                await onSave(parsed.clamp(min, max));
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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


          // ── SMART RECOMMENDATIONS ────────────────────────────────
          if (p.hasGoalRecommendations) ...[
            _Header('Smart Recommendations'),
            _SmartGoalsTile(p: p),
            const SizedBox(height: 20),
          ],

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

          // ── AI COACH ──────────────────────────────────────────────
          _Header('AI Coach'),
          _AiCoachEnabledTile(),
          if (p.aiCoachEnabled) ...[
            const SizedBox(height: 8),
            const _AiStatusTile(),
            const SizedBox(height: 8),
            _AiAutoLoadTile(),
          ],
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
              boxShadow: AppShadows.card,
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
            subtitle: '$kAppVersionLabel — Personal fitness tracker',
            onTap: null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Smart goal recommendations tile ─────────────────────────────────────────

class _SmartGoalsTile extends StatelessWidget {
  final FitnessProvider p;
  const _SmartGoalsTile({required this.p});

  @override
  Widget build(BuildContext context) {
    final rCal  = p.recommendedCalorieGoal?.round();
    final rProt = p.recommendedProteinGoal;
    final rWat  = p.recommendedWaterGoal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
        border: Border.all(color: const Color(0xFF40C8E0).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.science_rounded, size: 16, color: Color(0xFF40C8E0)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Calculated from your body data',
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          p.isTdeeCalibrated
              ? 'Calorie target is calibrated from your REAL weight trend + intake '
                '(not a generic formula). Protein & water scale with your body:'
              : 'Your current goals vs what your body metrics suggest:',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),

        // Calorie row
        if (rCal != null)
          _RecoRow(
            emoji: '🔥',
            label: 'Calories',
            current: '${p.calorieGoal} kcal',
            recommended: '$rCal kcal',
            reason: p.isTdeeCalibrated
                ? 'Real maintenance ${p.bestTdee?.round() ?? "—"} kcal − 500 ✓ calibrated'
                : 'Est. TDEE ${p.bestTdee?.round() ?? "—"} kcal − 500 (0.5 kg/wk loss)',
            matches: (rCal - p.calorieGoal).abs() <= 50,
          ),

        // Protein row
        _RecoRow(
          emoji: '💪',
          label: 'Protein',
          current: '${p.proteinGoal}g',
          recommended: '${rProt}g',
          reason: p.leanMassKg != null
              ? '2.0 g × ${p.leanMassKg!.toStringAsFixed(1)} kg lean mass'
              : '1.8 g × ${p.latestWeightKg?.toStringAsFixed(1) ?? "?"}kg body weight',
          matches: (rProt - p.proteinGoal).abs() <= 5,
        ),

        // Water row
        _RecoRow(
          emoji: '💧',
          label: 'Water',
          current: '${p.waterGoalMl} ml',
          recommended: '$rWat ml',
          reason: '35 ml × ${p.latestWeightKg?.toStringAsFixed(1) ?? "?"}kg body weight',
          matches: (rWat - p.waterGoalMl).abs() <= 150,
        ),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (rCal != null) await p.saveCalorieGoal(rCal);
              await p.saveProteinGoal(rProt);
              await p.saveWaterGoal(rWat);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Goals updated from your body data'),
                    backgroundColor: Color(0xFF30D158),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Apply Recommendations'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF30D158),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RecoRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String current;
  final String recommended;
  final String reason;
  final bool   matches;
  const _RecoRow({required this.emoji, required this.label, required this.current,
      required this.recommended, required this.reason, required this.matches});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$label: ',
                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                Text(current,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Text(' → ',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                Text(recommended,
                    style: TextStyle(
                        color: matches
                            ? const Color(0xFF30D158)
                            : const Color(0xFF40C8E0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                if (matches)
                  const Text('  ✓',
                      style: TextStyle(color: Color(0xFF30D158), fontSize: 11)),
              ]),
              Text(reason,
                  style: const TextStyle(
                      color: Color(0xFF8E8E93), fontSize: 10, height: 1.3)),
            ]),
          ),
        ]),
      );
}

// ── AI Coach status tile ──────────────────────────────────────────────────────

class _AiStatusTile extends StatelessWidget {
  const _AiStatusTile();

  static const _kGreen  = Color(0xFF30D158);
  static const _kCard   = Color(0xFF1C1C1E);
  static const _kSecond = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<OnDeviceAiService>();
    final isDownloading = ai.state == AiModelState.downloading;
    final isLoading     = ai.state == AiModelState.loading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ai.isReady
              ? _kGreen.withValues(alpha: 0.4)
              : _kSecond.withValues(alpha: 0.15),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🤖', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gemma 3 1B  ·  ~600 MB  ·  offline',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(ai.isReady ? 'Ready — tap to chat' : ai.state == AiModelState.notInstalled
                ? 'Download once over Wi-Fi to enable AI chat'
                : ai.state == AiModelState.downloading ? 'Downloading…'
                : ai.state == AiModelState.loading ? 'Loading model…'
                : 'Error',
                style: const TextStyle(color: _kSecond, fontSize: 11, height: 1.4)),
          ])),
          _StatusChip(ai.state),
        ]),

        // Download progress bar
        if (isDownloading) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ai.dlProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFF2C2C2E),
              valueColor: const AlwaysStoppedAnimation(_kGreen),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(ai.dlProgress * 100).round()}% · ${(ai.dlProgress * 600).round()} / ~600 MB',
              style: const TextStyle(color: _kSecond, fontSize: 11)),
        ],

        // Error message
        if (ai.state == AiModelState.error && ai.errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(ai.errorMessage,
              style: const TextStyle(color: Color(0xFFFF453A), fontSize: 11)),
        ],

        // Action buttons
        if (isDownloading) ...[
          // Issue #9: Cancel button (visible only when downloading)
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.read<OnDeviceAiService>().cancelDownload(),
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFFF453A)),
              label: const Text('Cancel Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF453A),
                side: const BorderSide(color: Color(0xFFFF453A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ] else if (ai.state == AiModelState.error) ...[
          // Issue #10: Retry button (visible only when error)
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.read<OnDeviceAiService>().downloadAndLoad(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Download'),
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ai.isReady
                ? OutlinedButton.icon(
                    onPressed: () => openChat(context),
                    icon: const Text('💬', style: TextStyle(fontSize: 14)),
                    label: const Text('Open AI Coach Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGreen,
                      side: const BorderSide(color: _kGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  )
                : isLoading
                    ? const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2)))
                    : FilledButton.icon(
                        onPressed: () => context.read<OnDeviceAiService>().downloadAndLoad(),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download AI Model (~600 MB)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
          ),
        ],
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AiModelState state;
  const _StatusChip(this.state);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      AiModelState.ready        => ('● Ready',      const Color(0xFF30D158)),
      AiModelState.downloading  => ('↓ Downloading', Colors.orange),
      AiModelState.loading      => ('⟳ Loading',    Colors.orange),
      AiModelState.error        => ('✕ Error',       const Color(0xFFFF453A)),
      AiModelState.notInstalled => ('Not installed', const Color(0xFF8E8E93)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
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
    // Material (clipped to the rounded shape) carries the colour so the
    // ListTile's ink splashes paint on it and stay visible — wrapping a
    // ListTile directly in a coloured DecoratedBox hides the ink.
    child: Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
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
    ),
  );
}

// ── AI Coach enable/disable toggle ────────────────────────────────────────────
class _AiCoachEnabledTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    return Material(
      // Material carries the colour so the SwitchListTile's ink stays visible.
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: const Icon(Icons.smart_toy_rounded, color: Color(0xFF30D158)),
        title: const Text('Enable AI Coach',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          p.aiCoachEnabled
              ? 'Shown on Home and available for chat'
              : 'Hidden from Home — turn on to use the coach again',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
        ),
        value: p.aiCoachEnabled,
        activeColor: const Color(0xFF30D158),
        onChanged: (v) => context.read<FitnessProvider>().saveAiCoachEnabled(v),
      ),
    );
  }
}

// ── AI Auto-load toggle ───────────────────────────────────────────────────────
class _AiAutoLoadTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ai = context.watch<OnDeviceAiService>();
    return Material(
      // Material carries the colour so the SwitchListTile's ink stays visible.
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: const Icon(Icons.bolt_rounded, color: Color(0xFF30D158)),
        title: const Text('Load AI at app start',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          ai.autoLoad
              ? 'AI is ready before you open it'
              : 'AI loads only when you open AI Coach',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
        ),
        value: ai.autoLoad,
        activeColor: const Color(0xFF30D158),
        onChanged: (v) => context.read<OnDeviceAiService>().saveAutoLoad(v),
      ),
    );
  }
}
