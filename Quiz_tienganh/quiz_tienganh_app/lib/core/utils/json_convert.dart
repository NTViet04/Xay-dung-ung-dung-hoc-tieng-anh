/// Chuẩn hóa số từ JSON — trên web `dart:convert` đôi khi trả [String] cho số.
int? parseJsonInt(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  if (v is num) {
    return v.toInt();
  }
  if (v is String) {
    final t = v.trim();
    // MySQL DECIMAL / JSON đôi khi là "8.0" hoặc "8.33" — int.tryParse thất bại → tiến độ 0%.
    if (t.contains('.')) {
      return double.tryParse(t)?.round();
    }
    return int.tryParse(t);
  }
  return null;
}

double? parseJsonDouble(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is double) {
    return v;
  }
  if (v is int) {
    return v.toDouble();
  }
  if (v is num) {
    return v.toDouble();
  }
  if (v is String) {
    return double.tryParse(v.trim());
  }
  return null;
}
