import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

class SmartScaleScreen extends StatefulWidget {
  const SmartScaleScreen({super.key});
  @override
  State<SmartScaleScreen> createState() => _SmartScaleScreenState();
}

class _SmartScaleScreenState extends State<SmartScaleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scale'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Log Today'),
            Tab(text: 'History'),
          ],
          indicatorColor: Color(0xFF30D158),
          labelColor: Color(0xFF30D158),
          unselectedLabelColor: Color(0xFF8E8E93),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _LogTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

class _LogTab extends StatefulWidget {
  const _LogTab();
  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();

  final _weight = TextEditingController();
  final _bodyFatPct = TextEditingController();
  final _bodyFatKg = TextEditingController();
  final _muscleMassKg = TextEditingController();
  final _muscleMassPct = TextEditingController();
  final _leanBodyMass = TextEditingController();
  final _bioAge = TextEditingController();
  final _visceralFat = TextEditingController();
  final _bmr = TextEditingController();
  final _bodyWater = TextEditingController();
  final _boneMass = TextEditingController();
  final _proteinPct = TextEditingController();
  final _skeletalMuscle = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (!mounted) return;
    // Only prefill if ALL fields are empty (don't overwrite user edits)
    if (_weight.text.isNotEmpty) return;
    final latest = context.read<FitnessProvider>().latestScaleEntry;
    if (latest == null) return;
    setState(() {
      _weight.text = latest.weightKg.toStringAsFixed(1);
      _bodyFatPct.text = latest.bodyFatPercent.toStringAsFixed(1);
      _bodyFatKg.text = latest.bodyFatKg.toStringAsFixed(1);
      _muscleMassKg.text = latest.muscleMassKg.toStringAsFixed(1);
      _muscleMassPct.text = latest.muscleMassPercent.toStringAsFixed(1);
      _leanBodyMass.text = latest.leanBodyMassKg.toStringAsFixed(1);
      _bioAge.text = latest.biologicalAge.toString();
      _visceralFat.text = latest.visceralFatIndex.toString();
      _bmr.text = latest.bmr.toStringAsFixed(0);
      _bodyWater.text = latest.bodyWaterPercent.toStringAsFixed(1);
      _boneMass.text = latest.boneMassKg.toStringAsFixed(2);
      _proteinPct.text = latest.proteinPercent.toStringAsFixed(1);
      _skeletalMuscle.text = latest.skeletalMuscleMassKg.toStringAsFixed(1);
    });
  }

  @override
  void dispose() {
    for (final c in [_weight, _bodyFatPct, _bodyFatKg, _muscleMassKg,
        _muscleMassPct, _leanBodyMass, _bioAge, _visceralFat, _bmr,
        _bodyWater, _boneMass, _proteinPct, _skeletalMuscle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    final weightVal = double.tryParse(_weight.text);
    if (weightVal == null) return; // form validator should catch this, but guard anyway
    final entry = SmartScaleEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      weightKg: weightVal,
      bodyFatPercent: double.tryParse(_bodyFatPct.text) ?? 0,
      bodyFatKg: double.tryParse(_bodyFatKg.text) ?? 0,
      muscleMassKg: double.tryParse(_muscleMassKg.text) ?? 0,
      muscleMassPercent: double.tryParse(_muscleMassPct.text) ?? 0,
      leanBodyMassKg: double.tryParse(_leanBodyMass.text) ?? 0,
      biologicalAge: int.tryParse(_bioAge.text) ?? 0,
      visceralFatIndex: int.tryParse(_visceralFat.text) ?? 0,
      bmr: double.tryParse(_bmr.text) ?? 0,
      bodyWaterPercent: double.tryParse(_bodyWater.text) ?? 0,
      boneMassKg: double.tryParse(_boneMass.text) ?? 0,
      proteinPercent: double.tryParse(_proteinPct.text) ?? 0,
      skeletalMuscleMassKg: double.tryParse(_skeletalMuscle.text) ?? 0,
    );
    await context.read<FitnessProvider>().logScaleEntry(entry);
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scale data saved! BMI and calorie targets updated.'),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final latest = context.watch<FitnessProvider>().latestScaleEntry;
    final subtitle = latest != null
        ? 'Pre-filled from ${latest.date.day}/${latest.date.month}/${latest.date.year} — update changed values'
        : 'Enter today\'s scale readings';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle,
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
            const SizedBox(height: 16),
            _Section('Essential', [
              _Field('Weight (kg)', _weight, required: true, hint: '70.0'),
              _Field('Body Fat (%)', _bodyFatPct, hint: '18.5'),
              _Field('Body Fat (kg)', _bodyFatKg, hint: '13.0'),
              _Field('BMR (kcal)', _bmr, hint: '1650'),
            ]),
            _Section('Muscle & Lean Mass', [
              _Field('Muscle Mass (kg)', _muscleMassKg, hint: '52.0'),
              _Field('Muscle Mass (%)', _muscleMassPct, hint: '74.0'),
              _Field('Lean Body Mass (kg)', _leanBodyMass, hint: '57.0'),
              _Field('Skeletal Muscle (kg)', _skeletalMuscle, hint: '28.0'),
            ]),
            _Section('Other Metrics', [
              _Field('Body Water (%)', _bodyWater, hint: '55.0'),
              _Field('Bone Mass (kg)', _boneMass, hint: '2.5'),
              _Field('Protein (%)', _proteinPct, hint: '17.5'),
              _Field('Visceral Fat Index', _visceralFat, hint: '8', isDecimal: false),
              _Field('Biological Age (yrs)', _bioAge, hint: '24', isDecimal: false),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Scale Data',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _Section(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(title,
              style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        ...fields,
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _Field(String label, TextEditingController ctrl,
      {bool required = false, String hint = '', bool isDecimal = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: required ? '＊' : null,
          suffixStyle: const TextStyle(color: Color(0xFFFF453A)),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty || double.tryParse(v) == null)
                ? 'Required'
                : null
            : null,
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();
  @override
  Widget build(BuildContext context) {
    final history = context.watch<FitnessProvider>().scaleHistory.reversed.toList();
    if (history.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('⚖️', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('No scale data yet', style: TextStyle(color: Color(0xFF8E8E93))),
          Text('Log your first reading above',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (ctx, i) {
        final e = history[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${e.date.day}/${e.date.month}/${e.date.year}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('${e.weightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF30D158))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _Pill('Fat ${e.bodyFatPercent.toStringAsFixed(1)}%', const Color(0xFFFF9F0A)),
              _Pill('Muscle ${e.muscleMassKg.toStringAsFixed(1)}kg', const Color(0xFF30D158)),
              _Pill('Water ${e.bodyWaterPercent.toStringAsFixed(1)}%', const Color(0xFF40C8E0)),
              _Pill('BMR ${e.bmr.toStringAsFixed(0)} kcal', const Color(0xFF5E5CE6)),
              _Pill('Bio Age ${e.biologicalAge}', Colors.white54),
              _Pill('Visceral ${e.visceralFatIndex}', Colors.white54),
            ]),
          ]),
        );
      },
    );
  }

  Widget _Pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
