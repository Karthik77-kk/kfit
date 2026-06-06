import 'package:flutter/material.dart';
import 'stats_screen.dart';
import 'smart_scale_screen.dart';

/// Merged Body tab — combines Stats (weight, 1RM, measurements) and Smart Scale
/// (body composition) into a single tab with an inner TabBar.
/// Replaces the former separate Body + Stats bottom-nav tabs.
class BodyScreen extends StatelessWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          title: const Text('Body'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stats'),
              Tab(text: 'Smart Scale'),
            ],
            indicatorColor: Color(0xFF30D158),
            labelColor: Color(0xFF30D158),
            unselectedLabelColor: Color(0xFF8E8E93),
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),
        body: const TabBarView(
          children: [
            StatsScreen(embedded: true),
            SmartScaleScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
