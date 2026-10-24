import '../../domain/activity.dart';
import '../../domain/connections.dart';
import '../../domain/goal.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';

/// Fictional sample content for the demo and for local backend seeding.
///
/// Every person, group, business and message here is invented. None is a
/// real member, job opening, partnership or endorsement. Identifiers are
/// stable UUIDs; timestamps are relative to [SeedData.build]'s `seededAt` so
/// the demo stays fresh while remaining deterministic for a given time.
abstract final class SeedIds {
  static String profile(int n) => '11111111-1111-4111-8111-${_pad(n)}';
  static String listing(int n) => '22222222-2222-4222-8222-${_pad(n)}';
  static String request(int n) => '33333333-3333-4333-8333-${_pad(n)}';
  static String conversation(int n) => '44444444-4444-4444-8444-${_pad(n)}';
  static String message(int n) => '55555555-5555-4555-8555-${_pad(n)}';
  static String event(int n) => '66666666-6666-4666-8666-${_pad(n)}';

  static String _pad(int n) => n.toString().padLeft(12, '0');

  // Named people used by docs and tests.
  static final amina = profile(1);
  static final yusuf = profile(2);
  static final fatima = profile(3);
  static final omar = profile(4);
  static final sarah = profile(5);
  static final bilal = profile(6);
  static final hana = profile(7);
  static final ibrahim = profile(8);
  static final maryam = profile(9);
  static final zaid = profile(10);
  static final khadija = profile(11);
  static final hassan = profile(12);
}

class SeedSnapshot {
  const SeedSnapshot({
    required this.profiles,
    required this.listings,
    required this.saved,
    required this.requests,
    required this.conversations,
    required this.messages,
    required this.events,
  });

  final List<Profile> profiles;
  final List<Listing> listings;
  final List<SavedListing> saved;
  final List<ConnectionRequest> requests;
  final List<Conversation> conversations;
  final List<Message> messages;
  final List<ActivityEvent> events;
}

abstract final class SeedData {
  static const accountEmailDomain = 'example.test';

  static SeedSnapshot build(DateTime seededAt) {
    DateTime ago({int days = 0, int hours = 0, int minutes = 0}) => seededAt
        .subtract(Duration(days: days, hours: hours, minutes: minutes))
        .toUtc();

    Profile p(
      int n, {
      required String name,
      required String headline,
      List<String> skills = const [],
      List<String> interests = const [],
      String offering = '',
      String seeking = '',
      List<Goal> goals = const [],
      String? area,
      bool remote = false,
      String? affiliation,
      bool visible = true,
      int joinedDaysAgo = 60,
    }) => Profile(
      id: SeedIds.profile(n),
      displayName: name,
      headline: headline,
      skills: skills,
      interests: interests,
      offeringSummary: offering,
      seekingSummary: seeking,
      goals: goals,
      areaId: area,
      openToRemote: remote,
      communityAffiliation: affiliation,
      directoryVisible: visible,
      onboardingComplete: true,
      isSample: true,
      createdAt: ago(days: joinedDaysAgo),
      updatedAt: ago(days: joinedDaysAgo ~/ 2),
    );

    const seek = GoalRole.seeking;
    const offer = GoalRole.offering;

    final profiles = <Profile>[
      p(
        1,
        name: 'Amina Rahman',
        headline: 'Engineering student who loves robotics',
        skills: ['Python', 'CAD'],
        interests: ['Robotics', 'Renewable energy'],
        offering: 'I can help high school students get started with Python.',
        seeking: 'A robotics mentor and a summer engineering internship.',
        goals: const [
          Goal(
            type: ListingType.mentorship,
            role: seek,
            subjects: ['Robotics'],
          ),
          Goal(
            type: ListingType.internship,
            role: seek,
            subjects: ['Engineering'],
          ),
          Goal(type: ListingType.service, role: offer, subjects: ['Python']),
        ],
        area: 'new-brunswick',
        remote: true,
        affiliation: 'Attends a masjid in New Brunswick',
      ),
      p(
        2,
        name: 'Yusuf Karim',
        headline: 'Mechanical engineer who mentors students in robotics',
        skills: ['Mechanical engineering', 'CAD', 'Robotics'],
        interests: ['STEM education', 'Hackathons'],
        offering:
            'Mentoring students in robotics, CAD and engineering careers.',
        seeking: 'Volunteer opportunities that use my engineering background.',
        goals: const [
          Goal(
            type: ListingType.mentorship,
            role: offer,
            subjects: ['Robotics', 'CAD'],
          ),
          Goal(
            type: ListingType.volunteer,
            role: seek,
            subjects: ['Engineering'],
          ),
        ],
        area: 'piscataway',
        remote: true,
        affiliation: 'Attends a masjid in Piscataway',
      ),
      p(
        3,
        name: 'Fatima Siddiqui',
        headline: 'Math and physics tutor for grades 8–12',
        skills: ['Math', 'Physics', 'Calculus', 'Tutoring', 'Quran'],
        interests: ['Writing'],
        offering:
            'Tutoring in algebra, calculus and physics, and Quran reading for kids.',
        seeking: 'A designer to make flyers for my tutoring sessions.',
        goals: const [
          Goal(
            type: ListingType.service,
            role: offer,
            subjects: ['Math', 'Physics', 'Calculus', 'Quran'],
          ),
          Goal(
            type: ListingType.service,
            role: seek,
            subjects: ['Graphic design'],
          ),
        ],
        area: 'edison',
        remote: true,
        affiliation: 'Attends a masjid in Edison',
      ),
      p(
        4,
        name: 'Omar Haddad',
        headline: 'Baker and caterer in East Brunswick',
        skills: ['Baking', 'Catering', 'Small business'],
        interests: ['Food pantry', 'Event planning'],
        offering: 'Fresh bread, pastries and catering for community events.',
        seeking:
            'Part-time counter help and volunteers for our monthly food pantry.',
        goals: const [
          Goal(
            type: ListingType.business,
            role: offer,
            subjects: ['Baking', 'Catering'],
          ),
          Goal(type: ListingType.job, role: offer),
          Goal(
            type: ListingType.volunteer,
            role: offer,
            subjects: ['Food pantry'],
          ),
        ],
        area: 'east-brunswick',
      ),
      p(
        5,
        name: 'Sarah Ahmed',
        headline: 'Accountant helping families and small businesses',
        skills: ['Accounting', 'Tax preparation', 'Bookkeeping', 'Excel'],
        interests: ['Small business', 'Finance'],
        offering:
            'Tax preparation, bookkeeping, and mentoring for women starting businesses.',
        seeking:
            'A website for my practice and a part-time administrative assistant.',
        goals: const [
          Goal(
            type: ListingType.service,
            role: offer,
            subjects: ['Tax preparation', 'Bookkeeping'],
          ),
          Goal(
            type: ListingType.mentorship,
            role: offer,
            subjects: ['Small business'],
          ),
          Goal(
            type: ListingType.service,
            role: seek,
            subjects: ['Web development'],
          ),
          Goal(
            type: ListingType.job,
            role: offer,
            subjects: ['Administrative support'],
          ),
        ],
        area: 'princeton',
        remote: true,
      ),
      p(
        6,
        name: 'Bilal Chaudhry',
        headline: 'Software developer building tools for local businesses',
        skills: [
          'JavaScript',
          'React',
          'Flutter',
          'Web development',
          'App development',
        ],
        interests: ['Small business', 'Machine learning'],
        offering:
            'Websites and apps for small businesses, and career mentorship for new developers.',
        seeking:
            'A co-founder for a halal food delivery app, and some part-time freelance work.',
        goals: const [
          Goal(
            type: ListingType.service,
            role: offer,
            subjects: ['Web development', 'App development'],
          ),
          Goal(
            type: ListingType.mentorship,
            role: offer,
            subjects: ['Software engineering', 'Career advice'],
          ),
          Goal(
            type: ListingType.collaboration,
            role: seek,
            subjects: ['Small business'],
          ),
          Goal(type: ListingType.job, role: seek, subjects: ['React']),
        ],
        area: 'plainsboro',
        remote: true,
      ),
      p(
        7,
        name: 'Hana Ali',
        headline: 'Coordinator of a youth robotics circle',
        skills: ['Event planning', 'Leadership'],
        interests: ['Robotics', 'Youth programs', 'STEM education'],
        offering:
            'A weekend robotics program for middle and high school students.',
        seeking: 'Volunteer mentors and STEM fair helpers.',
        goals: const [
          Goal(
            type: ListingType.volunteer,
            role: offer,
            subjects: ['Robotics', 'STEM education'],
          ),
        ],
        area: 'south-brunswick',
        affiliation:
            'Volunteers with a masjid youth program in South Brunswick',
      ),
      // Incomplete optional information and not in the directory.
      p(
        8,
        name: 'Ibrahim Patel',
        headline: '',
        skills: ['Electrical work', 'Home repair'],
        offering:
            'Electrical repairs and installs. I can also train an apprentice.',
        seeking: 'A reliable apprentice.',
        goals: const [
          Goal(
            type: ListingType.service,
            role: offer,
            subjects: ['Electrical work'],
          ),
          Goal(type: ListingType.job, role: offer),
        ],
        area: 'sayreville',
        visible: false,
      ),
      p(
        9,
        name: 'Maryam Hussain',
        headline: 'Graphic designer and event photographer',
        skills: ['Graphic design', 'Photography', 'Social media'],
        interests: ['Writing', 'Event planning'],
        offering: 'Logos, flyers and event photography.',
        seeking: 'Writers and photographers for a community magazine.',
        goals: const [
          Goal(
            type: ListingType.service,
            role: offer,
            subjects: ['Graphic design', 'Photography'],
          ),
          Goal(
            type: ListingType.collaboration,
            role: seek,
            subjects: ['Writing', 'Photography'],
          ),
        ],
        area: 'highland-park',
        remote: true,
      ),
      p(
        10,
        name: 'Zaid Mansour',
        headline: 'High school senior interested in medicine',
        interests: ['Pre-med', 'Biology', 'Youth programs'],
        offering: "I'd like to volunteer on weekends.",
        seeking:
            'A calculus tutor, a summer internship, and a mentor for the pre-med path.',
        goals: const [
          Goal(type: ListingType.service, role: seek, subjects: ['Calculus']),
          Goal(type: ListingType.internship, role: seek),
          Goal(type: ListingType.mentorship, role: seek, subjects: ['Pre-med']),
          Goal(type: ListingType.volunteer, role: seek),
        ],
        area: 'monroe',
        visible: false,
      ),
      p(
        11,
        name: 'Khadija Noor',
        headline: 'HR professional and career coach',
        skills: ['Resume review', 'Interview prep', 'Career advice'],
        interests: ['Leadership', 'Public speaking'],
        offering:
            'Resume reviews and mock interviews for students and career changers.',
        seeking: 'Volunteer opportunities teaching job-readiness workshops.',
        goals: const [
          Goal(
            type: ListingType.mentorship,
            role: offer,
            subjects: ['Resume review', 'Interview prep', 'Career advice'],
          ),
          Goal(
            type: ListingType.volunteer,
            role: seek,
            subjects: ['Career advice'],
          ),
        ],
        area: 'west-windsor',
        remote: true,
      ),
      p(
        12,
        name: 'Hassan Rizvi',
        headline: 'Runs a small IT and automation firm',
        skills: [
          'IT support',
          'Software engineering',
          'Electrical engineering',
        ],
        interests: ['Robotics', 'Hackathons'],
        offering:
            'IT support for small businesses and summer internships in software and automation.',
        seeking: 'Engineering interns and, later, a junior developer.',
        goals: const [
          Goal(
            type: ListingType.business,
            role: offer,
            subjects: ['IT support'],
          ),
          Goal(
            type: ListingType.internship,
            role: offer,
            subjects: ['Software engineering', 'Robotics'],
          ),
          Goal(
            type: ListingType.job,
            role: offer,
            subjects: ['Software engineering'],
          ),
        ],
        area: 'edison',
        affiliation: 'Attends a masjid in Edison',
      ),
    ];

    Listing l(
      int n,
      String owner, {
      required String title,
      required String description,
      required ListingType type,
      required ListingDirection direction,
      required ListingCategory category,
      List<String> tags = const [],
      String? area,
      bool remote = false,
      CompensationType? comp,
      String? compDetails,
      ListingStatus status = ListingStatus.active,
      required int daysAgo,
    }) {
      final created = ago(days: daysAgo, hours: n % 7);
      return Listing(
        id: SeedIds.listing(n),
        ownerId: owner,
        title: title,
        description: description,
        type: type,
        direction: direction,
        category: category,
        tags: tags,
        areaId: area,
        remoteAvailable: remote,
        compensationType: comp,
        compensationDetails: compDetails,
        status: status,
        createdAt: created,
        updatedAt: created,
        closedAt: status == ListingStatus.closed
            ? ago(days: daysAgo ~/ 2)
            : null,
        isSample: true,
      );
    }

    const o = ListingDirection.offer;
    const r = ListingDirection.request;

    final listings = <Listing>[
      l(
        1,
        SeedIds.yusuf,
        title: 'Robotics mentorship for students',
        description:
            "I'm a mechanical engineer who has worked on robot arms and competition robots. I can meet every other week to review your projects, CAD models and career questions. Happy to support high school and college students.",
        type: ListingType.mentorship,
        direction: o,
        category: ListingCategory.engineering,
        tags: ['robotics', 'cad', 'mechanical engineering', 'students'],
        area: 'piscataway',
        remote: true,
        comp: CompensationType.free,
        daysAgo: 3,
      ),
      l(
        2,
        SeedIds.bilal,
        title: 'Career mentorship for new software developers',
        description:
            'Monthly video calls for students and career changers learning software engineering: portfolio feedback, interview practice and how to choose a first role.',
        type: ListingType.mentorship,
        direction: o,
        category: ListingCategory.technology,
        tags: ['software engineering', 'career', 'interviews', 'javascript'],
        remote: true,
        comp: CompensationType.free,
        daysAgo: 12,
      ),
      l(
        3,
        SeedIds.khadija,
        title: 'Resume reviews and mock interviews',
        description:
            "I review resumes and run 45-minute mock interviews for students, new graduates and people changing careers. Bring a job description and we'll practice together.",
        type: ListingType.mentorship,
        direction: o,
        category: ListingCategory.careers,
        tags: ['resume', 'interview prep', 'career'],
        area: 'west-windsor',
        remote: true,
        comp: CompensationType.free,
        daysAgo: 6,
      ),
      l(
        4,
        SeedIds.sarah,
        title: 'Mentoring for women starting a small business',
        description:
            "Practical guidance on registering a business, bookkeeping basics and pricing your work. We'll meet monthly for three months.",
        type: ListingType.mentorship,
        direction: o,
        category: ListingCategory.business,
        tags: ['small business', 'bookkeeping', 'entrepreneurship'],
        area: 'princeton',
        remote: true,
        comp: CompensationType.free,
        daysAgo: 20,
      ),
      l(
        5,
        SeedIds.zaid,
        title: 'Looking for a mentor on the pre-med path',
        description:
            "I'm a high school senior thinking about medicine. I'd love advice from someone in healthcare about college choices, volunteering and shadowing.",
        type: ListingType.mentorship,
        direction: r,
        category: ListingCategory.health,
        tags: ['pre-med', 'healthcare', 'college'],
        area: 'monroe',
        remote: true,
        daysAgo: 5,
      ),
      l(
        6,
        SeedIds.amina,
        title: 'Seeking a robotics mentor for my senior design project',
        description:
            "Our team is building a small sorting robot. I'm looking for an experienced engineer to review our design every few weeks.",
        type: ListingType.mentorship,
        direction: r,
        category: ListingCategory.engineering,
        tags: ['robotics', 'senior design', 'engineering'],
        area: 'new-brunswick',
        remote: true,
        daysAgo: 4,
      ),
      l(
        7,
        SeedIds.hana,
        title: 'Volunteer robotics mentor needed for youth team',
        description:
            'Our youth robotics circle needs a volunteer mentor on Saturday mornings to help middle and high school students build and program robots for a regional competition.',
        type: ListingType.volunteer,
        direction: o,
        category: ListingCategory.community,
        tags: ['robotics', 'youth', 'volunteer', 'stem'],
        area: 'south-brunswick',
        comp: CompensationType.volunteer,
        daysAgo: 2,
      ),
      l(
        8,
        SeedIds.hana,
        title: 'Helpers for a weekend STEM fair',
        description:
            'We need volunteers to run activity tables, greet families and help with setup at a one-day STEM fair for kids.',
        type: ListingType.volunteer,
        direction: o,
        category: ListingCategory.community,
        tags: ['stem', 'youth', 'events'],
        area: 'edison',
        comp: CompensationType.volunteer,
        daysAgo: 9,
      ),
      l(
        9,
        SeedIds.omar,
        title: 'Monthly food pantry packing volunteers',
        description:
            'Join us on the first Sunday of each month to pack grocery boxes for families in need. No experience required; teens are welcome with a parent.',
        type: ListingType.volunteer,
        direction: o,
        category: ListingCategory.community,
        tags: ['food pantry', 'community service'],
        area: 'east-brunswick',
        comp: CompensationType.volunteer,
        daysAgo: 15,
      ),
      // Incomplete optional information: no tags or compensation.
      l(
        10,
        SeedIds.zaid,
        title: 'High school senior looking to volunteer on weekends',
        description:
            "I'm available on Saturdays and Sundays and would like to help with youth programs, tutoring younger kids or community events.",
        type: ListingType.volunteer,
        direction: r,
        category: ListingCategory.community,
        area: 'monroe',
        daysAgo: 8,
      ),
      l(
        11,
        SeedIds.hassan,
        title: 'Software engineering internship (summer)',
        description:
            "Paid summer internship building internal tools for small-business clients. You'll work with Python and JavaScript alongside our two developers. Computer science and engineering students are encouraged to apply.",
        type: ListingType.internship,
        direction: o,
        category: ListingCategory.technology,
        tags: ['software engineering', 'python', 'javascript', 'summer'],
        area: 'edison',
        remote: true,
        comp: CompensationType.paid,
        compDetails: r'$22/hr',
        daysAgo: 7,
      ),
      l(
        12,
        SeedIds.hassan,
        title: 'Engineering internship: automation and robotics (summer)',
        description:
            'Help us prototype automation for warehouse clients: wiring sensors, programming small robots and documenting tests. Ideal for engineering students who like hands-on work.',
        type: ListingType.internship,
        direction: o,
        category: ListingCategory.engineering,
        tags: ['robotics', 'automation', 'engineering', 'summer'],
        area: 'new-brunswick',
        comp: CompensationType.stipend,
        compDetails: 'Monthly stipend',
        daysAgo: 3,
      ),
      l(
        13,
        SeedIds.sarah,
        title: 'Accounting internship during tax season',
        description:
            'Part-time internship from January to April supporting tax preparation and bookkeeping. A good fit for accounting or finance students.',
        type: ListingType.internship,
        direction: o,
        category: ListingCategory.business,
        tags: ['accounting', 'tax preparation'],
        area: 'princeton',
        comp: CompensationType.paid,
        compDetails: r'$18/hr',
        daysAgo: 10,
      ),
      l(
        14,
        SeedIds.zaid,
        title: 'Rising senior seeking a summer internship',
        description:
            "Looking for a summer internship or shadowing opportunity in a clinic, lab or hospital. I'm reliable and eager to learn.",
        type: ListingType.internship,
        direction: r,
        category: ListingCategory.health,
        tags: ['pre-med', 'healthcare', 'summer'],
        area: 'monroe',
        daysAgo: 11,
      ),
      // Inactive: closed.
      l(
        15,
        SeedIds.maryam,
        title: 'Marketing and design internship',
        description:
            'Spring internship helping with social media and event photography. This position has been filled.',
        type: ListingType.internship,
        direction: o,
        category: ListingCategory.creative,
        tags: ['social media', 'graphic design'],
        area: 'highland-park',
        comp: CompensationType.unpaid,
        status: ListingStatus.closed,
        daysAgo: 40,
      ),
      l(
        16,
        SeedIds.omar,
        title: 'Part-time counter staff at the bakery',
        description:
            'Weekend mornings at the counter: greeting customers, packing orders and keeping the shop tidy. Training provided.',
        type: ListingType.job,
        direction: o,
        category: ListingCategory.food,
        tags: ['customer service', 'part-time', 'bakery'],
        area: 'east-brunswick',
        comp: CompensationType.paid,
        compDetails: r'$16/hr',
        daysAgo: 6,
      ),
      // Incomplete optional information: no compensation details.
      l(
        17,
        SeedIds.sarah,
        title: 'Part-time administrative assistant',
        description:
            'About 10 hours a week helping with scheduling, client documents and data entry. Comfortable with spreadsheets.',
        type: ListingType.job,
        direction: o,
        category: ListingCategory.business,
        tags: ['administrative', 'scheduling', 'excel'],
        area: 'princeton',
        remote: true,
        daysAgo: 14,
      ),
      l(
        18,
        SeedIds.ibrahim,
        title: 'Electrical apprentice',
        description:
            'Learn residential electrical work on real jobs: installing fixtures, running wire and troubleshooting. Must be reliable and comfortable on ladders.',
        type: ListingType.job,
        direction: o,
        category: ListingCategory.home,
        tags: ['electrical', 'apprentice', 'trades'],
        area: 'sayreville',
        comp: CompensationType.paid,
        compDetails: 'Hourly, based on experience',
        daysAgo: 18,
      ),
      l(
        19,
        SeedIds.bilal,
        title: 'Looking for part-time React work',
        description:
            'Experienced web developer available for 10 to 15 hours a week of freelance or part-time React and Flutter work.',
        type: ListingType.job,
        direction: r,
        category: ListingCategory.technology,
        tags: ['react', 'flutter', 'web development', 'freelance'],
        remote: true,
        daysAgo: 9,
      ),
      // Inactive: paused.
      l(
        20,
        SeedIds.hassan,
        title: 'Junior developer',
        description:
            'Full-time junior developer role supporting client projects. Hiring is paused while we finish current projects.',
        type: ListingType.job,
        direction: o,
        category: ListingCategory.technology,
        tags: ['software engineering', 'javascript'],
        area: 'edison',
        comp: CompensationType.paid,
        status: ListingStatus.paused,
        daysAgo: 30,
      ),
      l(
        21,
        SeedIds.fatima,
        title: 'Math and physics tutoring (grades 8–12)',
        description:
            'One-on-one tutoring in algebra, geometry, calculus and physics. Sessions at the library in Edison or online.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.education,
        tags: ['math', 'physics', 'calculus', 'tutoring'],
        area: 'edison',
        remote: true,
        comp: CompensationType.paid,
        compDetails: r'$35/hr',
        daysAgo: 5,
      ),
      l(
        22,
        SeedIds.fatima,
        title: 'Quran reading lessons for kids',
        description:
            'Patient, beginner-friendly Quran reading and tajweed lessons for children ages 6 to 12, online or in Edison.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.education,
        tags: ['quran', 'tajweed', 'kids'],
        area: 'edison',
        remote: true,
        comp: CompensationType.negotiable,
        compDetails: 'Sliding scale',
        daysAgo: 25,
      ),
      l(
        23,
        SeedIds.zaid,
        title: 'Need an AP Calculus tutor',
        description:
            'Looking for a calculus tutor for weekly sessions before the AP exam. Evenings work best.',
        type: ListingType.service,
        direction: r,
        category: ListingCategory.education,
        tags: ['calculus', 'tutoring'],
        area: 'monroe',
        remote: true,
        comp: CompensationType.paid,
        daysAgo: 2,
      ),
      l(
        24,
        SeedIds.sarah,
        title: 'Website for my bookkeeping practice',
        description:
            'I need a simple, professional website with a contact form and a page describing my services. Open to quotes.',
        type: ListingType.service,
        direction: r,
        category: ListingCategory.technology,
        tags: ['website', 'web development', 'small business'],
        area: 'princeton',
        remote: true,
        comp: CompensationType.paid,
        compDetails: 'Quote requested',
        daysAgo: 13,
      ),
      l(
        25,
        SeedIds.bilal,
        title: 'Websites and mobile apps for small businesses',
        description:
            'I build fast websites and Flutter apps for local businesses and nonprofits, from design to launch.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.technology,
        tags: ['web development', 'flutter', 'mobile apps'],
        area: 'plainsboro',
        remote: true,
        comp: CompensationType.paid,
        compDetails: 'Project-based',
        daysAgo: 16,
      ),
      l(
        26,
        SeedIds.maryam,
        title: 'Logos, flyers and event photography',
        description:
            'Branding, flyers and social media graphics, plus photography for community events and small businesses.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.creative,
        tags: ['graphic design', 'photography', 'branding', 'flyers'],
        area: 'highland-park',
        remote: true,
        comp: CompensationType.paid,
        daysAgo: 8,
      ),
      // Incomplete optional information: no compensation.
      l(
        27,
        SeedIds.ibrahim,
        title: 'Home electrical repairs and installs',
        description:
            'Light fixtures, outlets, ceiling fans and small electrical repairs in the Sayreville area.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.home,
        tags: ['electrical', 'home repair'],
        area: 'sayreville',
        daysAgo: 21,
      ),
      l(
        28,
        SeedIds.sarah,
        title: 'Tax preparation for individuals and small businesses',
        description:
            'Individual and small-business tax returns, plus bookkeeping cleanup. Virtual appointments available.',
        type: ListingType.service,
        direction: o,
        category: ListingCategory.business,
        tags: ['tax preparation', 'bookkeeping', 'accounting'],
        area: 'princeton',
        remote: true,
        comp: CompensationType.paid,
        daysAgo: 19,
      ),
      l(
        29,
        SeedIds.fatima,
        title: 'Designer needed for tutoring flyers',
        description:
            'Looking for someone to design a simple flyer and a social media post for my tutoring sessions.',
        type: ListingType.service,
        direction: r,
        category: ListingCategory.creative,
        tags: ['graphic design', 'flyers'],
        area: 'edison',
        remote: true,
        comp: CompensationType.paid,
        compDetails: 'Small budget',
        daysAgo: 4,
      ),
      l(
        30,
        SeedIds.bilal,
        title: 'Co-founder for a halal food delivery app',
        description:
            "I'm building an app that connects local halal restaurants with customers. Looking for a co-founder with business, marketing or operations experience.",
        type: ListingType.collaboration,
        direction: r,
        category: ListingCategory.technology,
        tags: ['startup', 'halal', 'mobile apps', 'marketing'],
        area: 'plainsboro',
        remote: true,
        daysAgo: 10,
      ),
      l(
        31,
        SeedIds.maryam,
        title: 'Writers and photographers for a community magazine',
        description:
            'Starting a quarterly community magazine featuring local stories, small businesses and events. Looking for writers and photographers to contribute.',
        type: ListingType.collaboration,
        direction: r,
        category: ListingCategory.creative,
        tags: ['writing', 'photography', 'community'],
        area: 'highland-park',
        remote: true,
        comp: CompensationType.unpaid,
        daysAgo: 7,
      ),
      l(
        32,
        SeedIds.amina,
        title: 'Teammates for a renewable energy hackathon',
        description:
            'Looking for two or three teammates for a weekend hackathon focused on solar and clean energy. Coders and designers welcome.',
        type: ListingType.collaboration,
        direction: r,
        category: ListingCategory.engineering,
        tags: ['hackathon', 'renewable energy', 'solar'],
        area: 'new-brunswick',
        daysAgo: 1,
      ),
      l(
        33,
        SeedIds.omar,
        title: 'Crescent Oven Bakery & Catering',
        description:
            'Fresh bread, pastries and halal catering for weddings, aqiqahs and community events. Order ahead for large trays.',
        type: ListingType.business,
        direction: o,
        category: ListingCategory.food,
        tags: ['halal', 'catering', 'bakery'],
        area: 'east-brunswick',
        comp: CompensationType.paid,
        daysAgo: 35,
      ),
      l(
        34,
        SeedIds.hassan,
        title: 'IT support and automation for small businesses',
        description:
            'Computer setup, networking, backups and simple automation for offices and shops.',
        type: ListingType.business,
        direction: o,
        category: ListingCategory.technology,
        tags: ['it support', 'networking', 'automation'],
        area: 'edison',
        remote: true,
        daysAgo: 28,
      ),
    ];

    final saved = <SavedListing>[
      SavedListing(
        userId: SeedIds.amina,
        listingId: SeedIds.listing(1),
        savedAt: ago(days: 2, hours: 3),
      ),
      SavedListing(
        userId: SeedIds.amina,
        listingId: SeedIds.listing(11),
        savedAt: ago(days: 1),
      ),
      SavedListing(
        userId: SeedIds.zaid,
        listingId: SeedIds.listing(21),
        savedAt: ago(days: 1, hours: 2),
      ),
    ];

    final requests = <ConnectionRequest>[
      ConnectionRequest(
        id: SeedIds.request(1),
        senderId: SeedIds.amina,
        recipientId: SeedIds.yusuf,
        listingId: SeedIds.listing(1),
        listingTitle: 'Robotics mentorship for students',
        message:
            "Assalamu alaikum! I'm working on a sorting robot for senior design and would love feedback on our gripper.",
        status: RequestStatus.accepted,
        createdAt: ago(days: 2, hours: 2),
        respondedAt: ago(days: 2),
        conversationId: SeedIds.conversation(1),
      ),
      ConnectionRequest(
        id: SeedIds.request(2),
        senderId: SeedIds.zaid,
        recipientId: SeedIds.fatima,
        listingId: SeedIds.listing(21),
        listingTitle: 'Math and physics tutoring (grades 8–12)',
        message:
            "Hi, I'm preparing for AP Calculus BC and would like weekly sessions. Are evenings available?",
        createdAt: ago(days: 1),
      ),
      ConnectionRequest(
        id: SeedIds.request(3),
        senderId: SeedIds.maryam,
        recipientId: SeedIds.bilal,
        listingId: SeedIds.listing(30),
        listingTitle: 'Co-founder for a halal food delivery app',
        message:
            'I could help with branding and photography for the app launch.',
        status: RequestStatus.declined,
        createdAt: ago(days: 8),
        respondedAt: ago(days: 7),
      ),
      ConnectionRequest(
        id: SeedIds.request(4),
        senderId: SeedIds.hana,
        recipientId: SeedIds.yusuf,
        message:
            'Salaam Yusuf! Our youth robotics circle would love a volunteer mentor. Would you consider joining us on Saturdays?',
        createdAt: ago(hours: 20),
      ),
      ConnectionRequest(
        id: SeedIds.request(5),
        senderId: SeedIds.sarah,
        recipientId: SeedIds.bilal,
        listingId: SeedIds.listing(25),
        listingTitle: 'Websites and mobile apps for small businesses',
        message:
            "Hi Bilal, I'd like a simple website for my practice. Could you send a rough quote?",
        status: RequestStatus.accepted,
        createdAt: ago(days: 5),
        respondedAt: ago(days: 4, hours: 20),
        conversationId: SeedIds.conversation(2),
      ),
    ];

    final messages = <Message>[
      Message(
        id: SeedIds.message(1),
        conversationId: SeedIds.conversation(1),
        senderId: SeedIds.yusuf,
        body:
            'Wa alaikum assalam, Amina. Happy to help. Could you share the CAD files before we meet?',
        createdAt: ago(days: 1, hours: 22),
        clientId: SeedIds.message(1),
      ),
      Message(
        id: SeedIds.message(2),
        conversationId: SeedIds.conversation(1),
        senderId: SeedIds.amina,
        body:
            "Yes, I'll send them tonight. Does Thursday evening work for a video call?",
        createdAt: ago(days: 1, hours: 21),
        clientId: SeedIds.message(2),
      ),
      Message(
        id: SeedIds.message(3),
        conversationId: SeedIds.conversation(1),
        senderId: SeedIds.yusuf,
        body: 'Thursday at 7 works. Talk then!',
        createdAt: ago(days: 1, hours: 20),
        clientId: SeedIds.message(3),
      ),
      Message(
        id: SeedIds.message(4),
        conversationId: SeedIds.conversation(2),
        senderId: SeedIds.bilal,
        body:
            "Thanks Sarah! I'll put a quote together this week. Do you already have a logo?",
        createdAt: ago(days: 4, hours: 18),
        clientId: SeedIds.message(4),
      ),
    ];

    Conversation conv(int n, ConnectionRequest req) {
      final last =
          messages
              .where((m) => m.conversationId == SeedIds.conversation(n))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final base = Conversation(
        id: SeedIds.conversation(n),
        requestId: req.id,
        participantIds: [req.senderId, req.recipientId],
        listingId: req.listingId,
        listingTitle: req.listingTitle,
        createdAt: req.respondedAt!,
      );
      return last.isEmpty ? base : base.withLastMessage(last.last);
    }

    final conversations = [conv(1, requests[0]), conv(2, requests[4])];

    final byId = {for (final x in listings) x.id: x};
    ActivityEvent ev(
      int n,
      String user,
      int listing,
      ActivityType type,
      DateTime at,
    ) {
      final x = byId[SeedIds.listing(listing)]!;
      return ActivityEvent(
        id: SeedIds.event(n),
        userId: user,
        listingId: x.id,
        type: type,
        listingType: x.type,
        category: x.category,
        tags: x.tags,
        createdAt: at,
      );
    }

    final events = <ActivityEvent>[
      ev(1, SeedIds.amina, 1, ActivityType.viewed, ago(days: 2, hours: 4)),
      ev(2, SeedIds.amina, 1, ActivityType.saved, ago(days: 2, hours: 3)),
      ev(
        3,
        SeedIds.amina,
        1,
        ActivityType.contactRequested,
        ago(days: 2, hours: 2),
      ),
      ev(4, SeedIds.amina, 11, ActivityType.saved, ago(days: 1)),
      ev(5, SeedIds.zaid, 21, ActivityType.saved, ago(days: 1, hours: 2)),
      ev(6, SeedIds.zaid, 21, ActivityType.contactRequested, ago(days: 1)),
    ];

    return SeedSnapshot(
      profiles: profiles,
      listings: listings,
      saved: saved,
      requests: requests,
      conversations: conversations,
      messages: messages,
      events: events,
    );
  }

  /// Local-only sign-in emails for seeded backend accounts.
  static String emailFor(Profile p) {
    final slug = p.displayName.toLowerCase().split(' ').first;
    return '$slug@$accountEmailDomain';
  }
}
