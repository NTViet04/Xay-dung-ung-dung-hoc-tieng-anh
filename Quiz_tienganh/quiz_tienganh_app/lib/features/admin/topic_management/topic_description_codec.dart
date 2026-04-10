/// Lưu phân loại trong `description` (API chỉ có `name` + `description`).
/// Định dạng: `CATEGORY:<tag>\nDESCRIPTION:<nội dung>`
abstract final class TopicDescriptionCodec {
  static const List<String> categoryOptions = [
    'Học thuật',
    'Chuyên ngành',
    'Khoa học',
    'Ngôn ngữ',
    'Chung',
  ];

  static (String category, String body) parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ('Chung', '');
    }
    final t = raw.trim();
    final re = RegExp(
      r'^CATEGORY:(.+?)\nDESCRIPTION:(.*)$',
      dotAll: true,
    );
    final m = re.firstMatch(t);
    if (m != null) {
      return (m.group(1)!.trim(), m.group(2)!.trim());
    }
    return ('Chung', t);
  }

  static String compose(String category, String body) {
    final b = body.trim();
    final c = category.trim().isEmpty ? 'Chung' : category.trim();
    if (c == 'Chung' && b.isEmpty) {
      return '';
    }
    if (c == 'Chung') {
      return b;
    }
    return 'CATEGORY:$c\nDESCRIPTION:$b';
  }
}
