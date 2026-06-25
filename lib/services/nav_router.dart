import 'package:flutter/foundation.dart';

/// Tiny ChangeNotifier that holds a "go here" navigation signal.
///
/// Consumers (main.dart, nutrition_screen.dart) listen to this and apply the
/// requested [tabIndex] / [nutritionSubTab] when [requestId] changes.
/// Using a monotonic [requestId] ensures that tapping the same route twice
/// still fires a change notification, so the tab always jumps to the right
/// position even if it was already on that tab.
class NavRouter extends ChangeNotifier {
  int tabIndex = 0;
  int nutritionSubTab = 0;
  int requestId = 0;

  /// Navigate to [route].
  ///
  /// Accepts either a bare route name (e.g. `"food"`) or a full URI string
  /// (e.g. `"kfit://food"`).  Unknown / empty routes fall back to Home (tab 0)
  /// without throwing.
  void open(String route) {
    // Strip a leading URI scheme so "kfit://food" → "food".
    final bare = route.contains('://')
        ? (Uri.tryParse(route)?.host ?? route)
        : route.trim().toLowerCase();

    switch (bare) {
      case 'home':
        tabIndex = 0;
        nutritionSubTab = 0;
      case 'food':
        tabIndex = 1;
        nutritionSubTab = 0;
      case 'water':
        tabIndex = 1;
        nutritionSubTab = 1;
      case 'supplements':
        tabIndex = 1;
        nutritionSubTab = 2;
      case 'workout':
        tabIndex = 2;
        nutritionSubTab = 0;
      case 'body':
        tabIndex = 3;
        nutritionSubTab = 0;
      case 'history':
        tabIndex = 4;
        nutritionSubTab = 0;
      default:
        // Unknown route → Home; do not throw.
        tabIndex = 0;
        nutritionSubTab = 0;
    }
    requestId++;
    notifyListeners();
  }
}
