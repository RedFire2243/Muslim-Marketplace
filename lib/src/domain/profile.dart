import 'goal.dart';
import 'json.dart';

/// The signed-in member's own, complete profile.
///
/// Other members only ever receive a [MemberProfile], which omits private
/// fields such as goals and personalization settings.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.headline = '',
    this.skills = const [],
    this.interests = const [],
    this.offeringSummary = '',
    this.seekingSummary = '',
    this.goals = const [],
    this.areaId,
    this.openToRemote = true,
    this.communityAffiliation,
    this.linkedinUrl,
    this.directoryVisible = false,
    this.personalizationEnabled = true,
    this.onboardingComplete = false,
    this.isSample = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;

  /// A one-line introduction, e.g. "Mechanical engineer who loves robotics".
  final String headline;
  final List<String> skills;
  final List<String> interests;
  final String offeringSummary;
  final String seekingSummary;

  /// Structured intents used for matching. Private to the member.
  final List<Goal> goals;

  /// Preferred area id from [Areas]; null when the member has not said.
  final String? areaId;

  /// Whether remote opportunities are welcome.
  final bool openToRemote;

  /// Self-reported masjid or organization. Not verified.
  final String? communityAffiliation;

  /// Optional link the member chose to share. Not an import.
  final String? linkedinUrl;

  /// Opt-in: appear in the member directory for signed-in members.
  final bool directoryVisible;

  /// Whether saves, requests, views and "show less" feedback adjust ranking.
  final bool personalizationEnabled;
  final bool onboardingComplete;

  /// Fictional seed content.
  final bool isSample;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  MemberProfile toMember() => MemberProfile(
    id: id,
    displayName: displayName,
    isSample: isSample,
    details: directoryVisible ? MemberDetails.fromProfile(this) : null,
  );

  Profile copyWith({
    String? displayName,
    String? headline,
    List<String>? skills,
    List<String>? interests,
    String? offeringSummary,
    String? seekingSummary,
    List<Goal>? goals,
    String? Function()? areaId,
    bool? openToRemote,
    String? Function()? communityAffiliation,
    String? Function()? linkedinUrl,
    bool? directoryVisible,
    bool? personalizationEnabled,
    bool? onboardingComplete,
    DateTime? updatedAt,
  }) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    headline: headline ?? this.headline,
    skills: skills ?? this.skills,
    interests: interests ?? this.interests,
    offeringSummary: offeringSummary ?? this.offeringSummary,
    seekingSummary: seekingSummary ?? this.seekingSummary,
    goals: goals ?? this.goals,
    areaId: areaId != null ? areaId() : this.areaId,
    openToRemote: openToRemote ?? this.openToRemote,
    communityAffiliation: communityAffiliation != null
        ? communityAffiliation()
        : this.communityAffiliation,
    linkedinUrl: linkedinUrl != null ? linkedinUrl() : this.linkedinUrl,
    directoryVisible: directoryVisible ?? this.directoryVisible,
    personalizationEnabled:
        personalizationEnabled ?? this.personalizationEnabled,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    isSample: isSample,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'headline': headline,
    'skills': skills,
    'interests': interests,
    'offeringSummary': offeringSummary,
    'seekingSummary': seekingSummary,
    'goals': [for (final g in goals) g.toJson()],
    'areaId': areaId,
    'openToRemote': openToRemote,
    'communityAffiliation': communityAffiliation,
    'linkedinUrl': linkedinUrl,
    'directoryVisible': directoryVisible,
    'personalizationEnabled': personalizationEnabled,
    'onboardingComplete': onboardingComplete,
    'isSample': isSample,
    'createdAt': writeDate(createdAt),
    'updatedAt': writeDate(updatedAt),
  };

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json['id'] as String,
    displayName: json['displayName'] as String? ?? '',
    headline: json['headline'] as String? ?? '',
    skills: readStrings(json['skills']),
    interests: readStrings(json['interests']),
    offeringSummary: json['offeringSummary'] as String? ?? '',
    seekingSummary: json['seekingSummary'] as String? ?? '',
    goals: [
      for (final g in (json['goals'] as List? ?? const []))
        Goal.fromJson(asJsonMap(g)),
    ],
    areaId: readOptionalString(json['areaId']),
    openToRemote: json['openToRemote'] as bool? ?? true,
    communityAffiliation: readOptionalString(json['communityAffiliation']),
    linkedinUrl: readOptionalString(json['linkedinUrl']),
    directoryVisible: json['directoryVisible'] as bool? ?? false,
    personalizationEnabled: json['personalizationEnabled'] as bool? ?? true,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    isSample: json['isSample'] as bool? ?? false,
    createdAt: readDate(json['createdAt']),
    updatedAt: readDate(json['updatedAt']),
  );
}

/// What other signed-in members may see about a person.
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.isSample = false,
    this.details,
  });

  final String id;
  final String displayName;
  final bool isSample;

  /// Present only when the member opted into the directory.
  final MemberDetails? details;

  bool get isDiscoverable => details != null;
}

/// Directory details, shared only by members who opted in.
class MemberDetails {
  const MemberDetails({
    this.headline = '',
    this.skills = const [],
    this.interests = const [],
    this.offeringSummary = '',
    this.seekingSummary = '',
    this.areaId,
    this.communityAffiliation,
    this.linkedinUrl,
  });

  factory MemberDetails.fromProfile(Profile p) => MemberDetails(
    headline: p.headline,
    skills: p.skills,
    interests: p.interests,
    offeringSummary: p.offeringSummary,
    seekingSummary: p.seekingSummary,
    areaId: p.areaId,
    communityAffiliation: p.communityAffiliation,
    linkedinUrl: p.linkedinUrl,
  );

  final String headline;
  final List<String> skills;
  final List<String> interests;
  final String offeringSummary;
  final String seekingSummary;
  final String? areaId;
  final String? communityAffiliation;
  final String? linkedinUrl;
}

/// Editable fields shared by onboarding and the profile editor.
class ProfileDraft {
  const ProfileDraft({
    this.displayName = '',
    this.headline = '',
    this.skills = const [],
    this.interests = const [],
    this.offeringSummary = '',
    this.seekingSummary = '',
    this.goals = const [],
    this.areaId,
    this.openToRemote = true,
    this.communityAffiliation,
    this.linkedinUrl,
    this.directoryVisible = false,
  });

  factory ProfileDraft.fromProfile(Profile p) => ProfileDraft(
    displayName: p.displayName,
    headline: p.headline,
    skills: p.skills,
    interests: p.interests,
    offeringSummary: p.offeringSummary,
    seekingSummary: p.seekingSummary,
    goals: p.goals,
    areaId: p.areaId,
    openToRemote: p.openToRemote,
    communityAffiliation: p.communityAffiliation,
    linkedinUrl: p.linkedinUrl,
    directoryVisible: p.directoryVisible,
  );

  final String displayName;
  final String headline;
  final List<String> skills;
  final List<String> interests;
  final String offeringSummary;
  final String seekingSummary;
  final List<Goal> goals;
  final String? areaId;
  final bool openToRemote;
  final String? communityAffiliation;
  final String? linkedinUrl;
  final bool directoryVisible;

  ProfileDraft copyWith({
    String? displayName,
    String? headline,
    List<String>? skills,
    List<String>? interests,
    String? offeringSummary,
    String? seekingSummary,
    List<Goal>? goals,
    String? Function()? areaId,
    bool? openToRemote,
    String? Function()? communityAffiliation,
    String? Function()? linkedinUrl,
    bool? directoryVisible,
  }) => ProfileDraft(
    displayName: displayName ?? this.displayName,
    headline: headline ?? this.headline,
    skills: skills ?? this.skills,
    interests: interests ?? this.interests,
    offeringSummary: offeringSummary ?? this.offeringSummary,
    seekingSummary: seekingSummary ?? this.seekingSummary,
    goals: goals ?? this.goals,
    areaId: areaId != null ? areaId() : this.areaId,
    openToRemote: openToRemote ?? this.openToRemote,
    communityAffiliation: communityAffiliation != null
        ? communityAffiliation()
        : this.communityAffiliation,
    linkedinUrl: linkedinUrl != null ? linkedinUrl() : this.linkedinUrl,
    directoryVisible: directoryVisible ?? this.directoryVisible,
  );

  /// Returns a map of field name to error message; empty when valid.
  Map<String, String> validate() {
    final errors = <String, String>{};
    final name = displayName.trim();
    if (name.isEmpty) {
      errors['displayName'] = 'Add the name other members will see.';
    } else if (name.length > 60) {
      errors['displayName'] = 'Keep your name under 60 characters.';
    }
    if (headline.length > 140) {
      errors['headline'] = 'Keep your introduction under 140 characters.';
    }
    final url = linkedinUrl?.trim() ?? '';
    if (url.isNotEmpty && !isValidLinkedInUrl(url)) {
      errors['linkedinUrl'] =
          'Use a full LinkedIn profile link, like https://www.linkedin.com/in/your-name';
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'headline': headline,
    'skills': skills,
    'interests': interests,
    'offeringSummary': offeringSummary,
    'seekingSummary': seekingSummary,
    'goals': [for (final g in goals) g.toJson()],
    'areaId': areaId,
    'openToRemote': openToRemote,
    'communityAffiliation': communityAffiliation,
    'linkedinUrl': linkedinUrl,
    'directoryVisible': directoryVisible,
  };

  factory ProfileDraft.fromJson(Map<String, Object?> json) => ProfileDraft(
    displayName: json['displayName'] as String? ?? '',
    headline: json['headline'] as String? ?? '',
    skills: readStrings(json['skills']),
    interests: readStrings(json['interests']),
    offeringSummary: json['offeringSummary'] as String? ?? '',
    seekingSummary: json['seekingSummary'] as String? ?? '',
    goals: [
      for (final g in (json['goals'] as List? ?? const []))
        Goal.fromJson(asJsonMap(g)),
    ],
    areaId: readOptionalString(json['areaId']),
    openToRemote: json['openToRemote'] as bool? ?? true,
    communityAffiliation: readOptionalString(json['communityAffiliation']),
    linkedinUrl: readOptionalString(json['linkedinUrl']),
    directoryVisible: json['directoryVisible'] as bool? ?? false,
  );
}

/// Accepts https://linkedin.com/in/... or https://www.linkedin.com/in/...
bool isValidLinkedInUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host != 'linkedin.com' && !host.endsWith('.linkedin.com')) return false;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return segments.length >= 2 && segments.first == 'in';
}
