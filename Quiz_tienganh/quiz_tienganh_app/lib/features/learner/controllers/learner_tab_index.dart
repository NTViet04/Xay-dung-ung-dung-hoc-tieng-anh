import 'package:flutter/foundation.dart';

/// Tab 0–3 cho vùng người học (Trang chủ / Chủ đề / Tiến độ / Hồ sơ).
/// Dùng với [IndexedStack] — không dùng [Navigator.pushReplacementNamed] để đổi tab
/// (tránh lỗi hit-test / mouse_tracker trên Web).
class LearnerTabIndex extends ChangeNotifier {
  LearnerTabIndex([int initial = 0]) : _index = initial.clamp(0, 2);

  int _index;
  int get index => _index;

  void goTo(int tab) {
    final t = tab.clamp(0, 2);
    if (t == _index) return;
    _index = t;
    notifyListeners();
  }
}
