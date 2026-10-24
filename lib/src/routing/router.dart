import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/inbox/conversation_screen.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/listing/listing_detail_screen.dart';
import '../features/listing/listing_form_screen.dart';
import '../features/members/member_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/my_listings_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/welcome/splash_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../state/data_providers.dart';
import '../state/session.dart';
import '../ui/theme.dart';
import 'app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicRoutes = {'/welcome', '/sign-in', '/sign-up'};

List<RouteBase> _sharedRoutes() => [
  GoRoute(
    path: 'listing/:id',
    builder: (context, state) =>
        ListingDetailScreen(listingId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        builder: (context, state) =>
            ListingFormScreen(editId: state.pathParameters['id']),
      ),
    ],
  ),
  GoRoute(path: 'post', builder: (context, state) => const ListingFormScreen()),
  GoRoute(
    path: 'member/:id',
    builder: (context, state) =>
        MemberScreen(memberId: state.pathParameters['id']!),
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(myProfileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final session = ref.read(sessionProvider);
    if (session.isLoading && !session.hasValue) {
      return loc == '/splash' ? null : '/splash';
    }
    if (session.value == null) {
      return _publicRoutes.contains(loc) ? null : '/welcome';
    }
    final profile = ref.read(myProfileProvider);
    if (!profile.hasValue && !profile.hasError) {
      // Wait for the profile before deciding on onboarding.
      return (_publicRoutes.contains(loc) || loc == '/splash')
          ? '/splash'
          : null;
    }
    final p = profile.value;
    if (p != null && !p.onboardingComplete) {
      return loc == '/onboarding' ? null : '/onboarding';
    }
    if (_publicRoutes.contains(loc) ||
        loc == '/splash' ||
        loc == '/onboarding') {
      return '/';
    }
    return null;
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const AuthScreen(mode: AuthMode.signIn),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const AuthScreen(mode: AuthMode.signUp),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
                routes: _sharedRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                builder: (context, state) => const SavedScreen(),
                routes: _sharedRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxScreen(),
                routes: [
                  GoRoute(
                    path: 'chat/:id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      if (Breakpoints.isExpanded(context)) {
                        return NoTransitionPage(
                          key: state.pageKey,
                          child: InboxScreen(selectedConversationId: id),
                        );
                      }
                      return MaterialPage(
                        key: state.pageKey,
                        child: ConversationScreen(conversationId: id),
                      );
                    },
                  ),
                  ..._sharedRoutes(),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const ProfileEditScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'listings',
                    builder: (context, state) => const MyListingsScreen(),
                  ),
                  ..._sharedRoutes(),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Navigation helpers that keep detail pages inside the current tab.
extension MarketplaceNavigation on BuildContext {
  /// The current tab's path prefix ('' for Discover), so detail pages open
  /// inside the tab the member is using.
  String get branchPrefix => _branchPrefix;

  String get _branchPrefix {
    final path = GoRouter.of(this).routerDelegate.currentConfiguration.uri.path;
    for (final prefix in const ['/saved', '/inbox', '/profile']) {
      if (path.startsWith(prefix)) return prefix;
    }
    return '';
  }

  void openListing(String id) => push('$_branchPrefix/listing/$id');
  void openListingEditor(String id) => push('$_branchPrefix/listing/$id/edit');
  void openPost() => push('$_branchPrefix/post');
  void openMember(String id) => push('$_branchPrefix/member/$id');
  void openConversation(String id) => go('/inbox/chat/$id');
}
