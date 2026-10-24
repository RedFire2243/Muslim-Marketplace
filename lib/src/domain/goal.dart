import 'taxonomy.dart';

/// What the member is doing with respect to an opportunity type.
enum GoalRole {
  /// The member wants to receive or obtain it (find a mentor, get a job).
  seeking('seeking'),

  /// The member provides it (mentor someone, hire, offer a service).
  offering('offering');

  const GoalRole(this.wire);
  final String wire;

  static GoalRole fromWire(String value) =>
      values.firstWhere((r) => r.wire == value, orElse: () => seeking);
}

/// One structured intent, such as "seeking mentorship in robotics".
///
/// Profiles keep a list of goals (one person can seek a mentor and offer
/// tutoring at the same time), and search requests produce goals too.
class Goal {
  const Goal({
    required this.type,
    required this.role,
    this.subjects = const [],
  });

  final ListingType type;
  final GoalRole role;

  /// Subject terms taken verbatim from the member's words, e.g. "robotics".
  final List<String> subjects;

  /// The listing direction that satisfies this goal for non-reciprocal types.
  /// Seeking X is served by someone offering X, and vice versa.
  ListingDirection get compatibleDirection => role == GoalRole.seeking
      ? ListingDirection.offer
      : ListingDirection.request;

  Goal copyWith({ListingType? type, GoalRole? role, List<String>? subjects}) =>
      Goal(
        type: type ?? this.type,
        role: role ?? this.role,
        subjects: subjects ?? this.subjects,
      );

  /// e.g. "Looking for mentorship" or "Offering a service".
  String get label {
    final verb = role == GoalRole.seeking ? 'Looking for' : 'Offering';
    final noun = switch ((type, role)) {
      (ListingType.service, GoalRole.seeking) => 'a service',
      (ListingType.service, GoalRole.offering) => 'a service',
      (ListingType.job, GoalRole.seeking) => 'a job',
      (ListingType.job, GoalRole.offering) => 'a job (hiring)',
      (ListingType.internship, GoalRole.seeking) => 'an internship',
      (ListingType.internship, GoalRole.offering) => 'an internship',
      (ListingType.mentorship, GoalRole.seeking) => 'a mentor',
      (ListingType.mentorship, GoalRole.offering) => 'mentorship',
      (ListingType.collaboration, GoalRole.seeking) => 'collaborators',
      (ListingType.collaboration, GoalRole.offering) => 'to collaborate',
      (ListingType.volunteer, GoalRole.seeking) => 'volunteer work',
      (ListingType.volunteer, GoalRole.offering) => 'volunteer roles',
      (ListingType.business, GoalRole.seeking) => 'local businesses',
      (ListingType.business, GoalRole.offering) => 'my business',
    };
    return '$verb $noun';
  }

  /// Label including subjects, e.g. "Looking for a mentor · robotics".
  String get fullLabel =>
      subjects.isEmpty ? label : '$label · ${subjects.join(', ')}';

  Map<String, Object?> toJson() => {
    'type': type.wire,
    'role': role.wire,
    'subjects': subjects,
  };

  factory Goal.fromJson(Map<String, Object?> json) => Goal(
    type: ListingType.fromWire(json['type'] as String? ?? 'service'),
    role: GoalRole.fromWire(json['role'] as String? ?? 'seeking'),
    subjects: _strings(json['subjects']),
  );

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.type == type &&
      other.role == role &&
      _listEquals(other.subjects, subjects);

  @override
  int get hashCode => Object.hash(type, role, Object.hashAll(subjects));

  @override
  String toString() => 'Goal($fullLabel)';
}

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
