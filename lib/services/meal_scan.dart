import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/fitness_provider.dart';
import '../screens/meal_scan_result_screen.dart';
import 'gemini_vision_service.dart';
import 'scan_quota.dart';

/// "Scan meal" entry point used by both buttons on the Food page.
/// Flow: quota check → camera capture → Gemini analysis → editable results.
Future<void> startMealScan(BuildContext context) async {
  if (!GeminiVisionService.isConfigured) {
    _snack(context, "AI photo scan isn't available in this build.");
    return;
  }
  final userName = context.read<FitnessProvider>().userName;
  final prefs = await SharedPreferences.getInstance();

  if (!ScanQuota.canScan(prefs, userName)) {
    if (context.mounted) _showExhausted(context);
    return;
  }

  XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 60, // compress for a fast, cheap upload
      maxWidth: 1280,
    );
  } catch (_) {
    if (context.mounted) _snack(context, "Couldn't open the camera.");
    return;
  }
  if (shot == null) return; // cancelled

  final bytes = await shot.readAsBytes();
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AnalyzingDialog(),
  );

  List<ScannedFood> foods;
  try {
    foods = await GeminiVisionService.analyze(bytes);
  } on GeminiException catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _snack(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _snack(context, 'Analysis failed. Please try again.');
    return;
  }
  if (context.mounted) Navigator.of(context).pop(); // close progress

  // Only a genuinely successful analysis burns a credit (owner is exempt).
  await ScanQuota.record(prefs, userName);

  if (foods.isEmpty) {
    if (context.mounted) {
      _snack(context, 'No food detected — try a clearer, closer photo.');
    }
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MealScanResultScreen(foods: foods)),
  );
}

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF2C2C2E)),
    );

void _showExhausted(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text("You've used today's scans"),
      content: Text(
        'AI meal scan is limited to ${ScanQuota.dailyLimit} photos per day. '
        'Your credits reset tomorrow — meanwhile you can still add food manually.',
        style: const TextStyle(color: Color(0xFF8E8E93), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it', style: TextStyle(color: Color(0xFF30D158))),
        ),
      ],
    ),
  );
}

class _AnalyzingDialog extends StatelessWidget {
  const _AnalyzingDialog();
  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      backgroundColor: Color(0xFF1C1C1E),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Color(0xFF30D158)),
          ),
          SizedBox(width: 16),
          Flexible(child: Text('Analysing your meal…')),
        ],
      ),
    );
  }
}
