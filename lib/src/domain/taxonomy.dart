/// Canonical marketplace vocabulary shared by demo and connected modes.
///
/// Three separate ideas describe every listing:
/// * [ListingType] — the kind of opportunity (a service, a job, mentorship…).
/// * [ListingDirection] — the poster's role: offering it or requesting it.
/// * [ListingCategory] — the subject area (education, technology…).
///
/// See docs/08-implementation-decisions.md for the full rationale.
library;

/// The kind of opportunity a listing describes.
enum ListingType {
  service('service'),
  job('job'),
  internship('internship'),
  mentorship('mentorship'),
  collaboration('collaboration'),
  volunteer('volunteer'),
  business('business');

  const ListingType(this.wire);

  /// Stable value stored in persistence and the database.
  final String wire;

  static ListingType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value, orElse: () => service);

  String get label => switch (this) {
    service => 'Service',
    job => 'Job',
    internship => 'Internship',
    mentorship => 'Mentorship',
    collaboration => 'Collaboration',
    volunteer => 'Volunteering',
    business => 'Local business',
  };

  String get pluralLabel => switch (this) {
    service => 'Services',
    job => 'Jobs',
    internship => 'Internships',
    mentorship => 'Mentorship',
    collaboration => 'Collaborations',
    volunteer => 'Volunteering',
    business => 'Local businesses',
  };

  /// Local businesses are directory entries: only the business itself posts
  /// them, so they are always offers. Someone looking for a business posts a
  /// service request instead.
  bool get allowsRequests => this != business;

  /// Collaboration is reciprocal: both directions describe people who want to
  /// work together, so matching treats them as mutually compatible.
  bool get isReciprocal => this == collaboration;

  /// Human label for the poster's role, e.g. "Hiring" or "Looking for a mentor".
  String directionLabel(ListingDirection direction) =>
      switch ((this, direction)) {
        (service, ListingDirection.offer) => 'Offering a service',
        (service, ListingDirection.request) => 'Looking for help',
        (job, ListingDirection.offer) => 'Hiring',
        (job, ListingDirection.request) => 'Looking for work',
        (internship, ListingDirection.offer) => 'Internship opening',
        (internship, ListingDirection.request) => 'Seeking an internship',
        (mentorship, ListingDirection.offer) => 'Offering mentorship',
        (mentorship, ListingDirection.request) => 'Looking for a mentor',
        (collaboration, ListingDirection.offer) => 'Open to collaborate',
        (collaboration, ListingDirection.request) => 'Seeking collaborators',
        (volunteer, ListingDirection.offer) => 'Volunteers needed',
        (volunteer, ListingDirection.request) => 'Wants to volunteer',
        (business, _) => 'Local business',
      };

  /// Describes the poster's role to other members (detail pages).
  String directionMeaning(ListingDirection direction) =>
      switch ((this, direction)) {
        (service, ListingDirection.offer) => 'They provide this service.',
        (service, ListingDirection.request) =>
          'They need someone to provide this service.',
        (job, ListingDirection.offer) => 'They have a position to fill.',
        (job, ListingDirection.request) => 'They are looking for a position.',
        (internship, ListingDirection.offer) => 'They can host an intern.',
        (internship, ListingDirection.request) =>
          'They are looking for an internship.',
        (mentorship, ListingDirection.offer) => 'They can mentor someone.',
        (mentorship, ListingDirection.request) => 'They would like a mentor.',
        (collaboration, ListingDirection.offer) =>
          'They are available to join a project.',
        (collaboration, ListingDirection.request) =>
          'They want people to join their project.',
        (volunteer, ListingDirection.offer) => 'Their group needs volunteers.',
        (volunteer, ListingDirection.request) =>
          'They would like to volunteer somewhere.',
        (business, _) => 'A local business listed by its owner.',
      };

  /// Explains each direction on the create-listing form.
  String directionHelp(ListingDirection direction) =>
      switch ((this, direction)) {
        (service, ListingDirection.offer) =>
          'You provide this service, such as tutoring or repairs.',
        (service, ListingDirection.request) =>
          'You need someone to provide a service for you.',
        (job, ListingDirection.offer) => 'You have a position to fill.',
        (job, ListingDirection.request) => 'You are looking for a position.',
        (internship, ListingDirection.offer) => 'You can host an intern.',
        (internship, ListingDirection.request) =>
          'You are looking for an internship.',
        (mentorship, ListingDirection.offer) => 'You can mentor someone.',
        (mentorship, ListingDirection.request) => 'You would like a mentor.',
        (collaboration, ListingDirection.offer) =>
          'You are available to join someone else\'s project.',
        (collaboration, ListingDirection.request) =>
          'You want people to join your project.',
        (volunteer, ListingDirection.offer) => 'Your group needs volunteers.',
        (volunteer, ListingDirection.request) =>
          'You would like to volunteer somewhere.',
        (business, _) => 'You run this business and want people to find it.',
      };
}

/// The poster's role in a listing.
enum ListingDirection {
  /// The poster makes something available: a service, an opening, mentorship,
  /// a volunteer role, or a business.
  offer('offer'),

  /// The poster is looking for something: help, a position, a mentor,
  /// collaborators, or a place to volunteer.
  request('request');

  const ListingDirection(this.wire);
  final String wire;

  static ListingDirection fromWire(String value) =>
      values.firstWhere((d) => d.wire == value, orElse: () => offer);

  ListingDirection get opposite => this == offer ? request : offer;

  String get label => this == offer ? 'Offer' : 'Request';
}

/// Subject area of a listing. Separate from [ListingType].
enum ListingCategory {
  education('education', 'Education & tutoring'),
  technology('technology', 'Technology & software'),
  engineering('engineering', 'Engineering & science'),
  business('business', 'Business & finance'),
  careers('careers', 'Careers & growth'),
  creative('creative', 'Design & media'),
  health('health', 'Health & wellness'),
  home('home', 'Home & repairs'),
  food('food', 'Food & catering'),
  community('community', 'Community & youth'),
  other('other', 'Other');

  const ListingCategory(this.wire, this.label);
  final String wire;
  final String label;

  static ListingCategory fromWire(String value) =>
      values.firstWhere((c) => c.wire == value, orElse: () => other);

  /// Short label for compact chips.
  String get shortLabel => switch (this) {
    education => 'Education',
    technology => 'Technology',
    engineering => 'Engineering',
    business => 'Business',
    careers => 'Careers',
    creative => 'Design & media',
    health => 'Health',
    home => 'Home',
    food => 'Food',
    community => 'Community',
    other => 'Other',
  };
}

/// How a listing is compensated, when the poster says.
enum CompensationType {
  paid('paid', 'Paid'),
  stipend('stipend', 'Stipend'),
  unpaid('unpaid', 'Unpaid'),
  volunteer('volunteer', 'Volunteer'),
  free('free', 'Free'),
  negotiable('negotiable', 'Negotiable');

  const CompensationType(this.wire, this.label);
  final String wire;
  final String label;

  static CompensationType? fromWire(String? value) {
    if (value == null) return null;
    for (final c in values) {
      if (c.wire == value) return c;
    }
    return null;
  }
}

/// Lifecycle of a listing.
enum ListingStatus {
  /// Visible in discovery and open to requests.
  active('active', 'Active'),

  /// Temporarily hidden by its owner; can be resumed.
  paused('paused', 'Paused'),

  /// No longer available. Terminal: closed listings cannot be reopened.
  closed('closed', 'Closed');

  const ListingStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ListingStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => closed);

  /// Valid transitions. Mirrored by the `enforce_listing_rules` database
  /// trigger in connected mode.
  bool canTransitionTo(ListingStatus next) => switch ((this, next)) {
    (active, paused) || (active, closed) => true,
    (paused, active) || (paused, closed) => true,
    _ => false,
  };
}

/// Lifecycle of a connection request.
enum RequestStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  withdrawn('withdrawn', 'Withdrawn');

  const RequestStatus(this.wire, this.label);
  final String wire;
  final String label;

  static RequestStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => pending);

  bool get isOpen => this == pending || this == accepted;
}

/// Who performs a request transition.
enum RequestActor { sender, recipient }

/// Valid request transitions: only the recipient accepts or declines, only
/// the sender withdraws, and only from [RequestStatus.pending]. Mirrored by
/// the `respond_to_connection_request` and `withdraw_connection_request`
/// database functions.
bool canTransitionRequest(
  RequestStatus from,
  RequestStatus to,
  RequestActor actor,
) {
  if (from != RequestStatus.pending) return false;
  return switch (to) {
    RequestStatus.accepted ||
    RequestStatus.declined => actor == RequestActor.recipient,
    RequestStatus.withdrawn => actor == RequestActor.sender,
    RequestStatus.pending => false,
  };
}
