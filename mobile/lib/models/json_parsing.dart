// model의 fromJson에서 반복해서 쓰는 안전한 parsing helper입니다.
// 백엔드가 확정되기 전에는 id나 금액이 int 또는 String으로 올 수 있다고 보고 처리합니다.

int parseJsonInt(dynamic value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Invalid int for $fieldName: $value');
}

int? parseNullableJsonInt(dynamic value, String fieldName) {
  if (value == null || value == '') {
    return null;
  }
  return parseJsonInt(value, fieldName);
}

double parseJsonDouble(
  dynamic value,
  String fieldName, {
  double defaultValue = 0.0,
}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Invalid double for $fieldName: $value');
}

DateTime? parseNullableDateTime(dynamic value) {
  if (value == null || value == '') {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  throw FormatException('Invalid DateTime: $value');
}

List<T> parseJsonList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) itemParser,
) {
  final list = value as List<dynamic>? ?? const [];
  return list
      .map((item) => itemParser(item as Map<String, dynamic>))
      .toList();
}
