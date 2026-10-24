/// Small helpers for reading loosely typed JSON maps safely.
library;

List<String> readStrings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const <String>[];

DateTime readDate(Object? value, {DateTime? fallback}) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? readOptionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

String? readOptionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? writeDate(DateTime? value) => value?.toUtc().toIso8601String();

Map<String, Object?> asJsonMap(Object? value) => value is Map
    ? value.map((key, v) => MapEntry(key.toString(), v))
    : <String, Object?>{};
