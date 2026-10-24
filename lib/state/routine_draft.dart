import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Rutina en edición, compartida entre el editor y la biblioteca en modo «elegir».
class RoutineDraft extends ChangeNotifier {
  RoutineDraft({this.id, String name = '', List<RoutineItem>? items})
    : _name = name,
      _items = List.of(items ?? const []);

  /// Id de la rutina que se edita; null si es nueva.
  final String? id;
  String _name;
  final List<RoutineItem> _items;

  String get name => _name;
  set name(String v) {
    _name = v;
    notifyListeners();
  }

  List<RoutineItem> get items => List.unmodifiable(_items);

  bool contains(String exId) => _items.any((i) => i.exerciseId == exId);

  void add(Exercise ex) {
    if (contains(ex.id)) return;
    _items.add(
      RoutineItem(
        exerciseId: ex.id,
        sets: 3,
        reps: ex.timed ? 30 : (ex.weighted ? 10 : 12),
      ),
    );
    notifyListeners();
  }

  void toggle(Exercise ex) {
    if (contains(ex.id)) {
      _items.removeWhere((i) => i.exerciseId == ex.id);
      notifyListeners();
    } else {
      add(ex);
    }
  }

  void removeAt(int i) {
    _items.removeAt(i);
    notifyListeners();
  }

  void move(int from, int to) {
    if (from == to) return;
    final item = _items.removeAt(from);
    _items.insert(to, item);
    notifyListeners();
  }
}
