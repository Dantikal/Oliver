import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/widgets/auth_transition.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/catalog/presentation/screens/comments_screen.dart';
import '../../features/catalog/presentation/screens/create_product_screen.dart';
import '../../features/catalog/presentation/screens/home_screen.dart';
import '../../features/catalog/presentation/screens/product_details_screen.dart';
import '../../features/chats/presentation/screens/chat_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/seller/presentation/seller_dashboard_screen.dart';
import '../../features/store/presentation/section_editor_screen.dart';
import '../../features/store/presentation/store_manage_screen.dart';
import '../../features/store/presentation/storefront_screen.dart';
import '../../features/shell/main_shell.dart';
import '../widgets/motion.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

const _authRoutes = {'/login', '/register', '/otp', '/forgot'};

/// Модальный слайд снизу для экрана создания объявления.
CustomTransitionPage<void> _modalPage(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: a,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic)),
        child: c,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier(ref.read(authControllerProvider).status);
  ref.listen(authControllerProvider, (_, next) => status.value = next.status);
  ref.onDispose(status.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: status,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (status.value) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          // Авто-логаут (в т.ч. по 401) → экран входа.
          return _authRoutes.contains(loc) ? null : '/login';
        case AuthStatus.authenticated:
          return (_authRoutes.contains(loc) || loc == '/splash')
              ? '/home'
              : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, s) =>
            NoTransitionPage(key: s.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) =>
            AuthTransitionPage(key: s.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, s) =>
            AuthTransitionPage(key: s.pageKey, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (_, s) {
          final extra = (s.extra as Map?) ?? const {};
          return AuthTransitionPage(
            key: s.pageKey,
            child: OtpScreen(
                sessionId: '${extra['sessionId'] ?? ''}',
                email: '${extra['email'] ?? ''}'),
          );
        },
      ),
      GoRoute(
        path: '/forgot',
        pageBuilder: (_, s) => AuthTransitionPage(
            key: s.pageKey,
            child: ForgotPasswordScreen(email: s.extra as String?)),
      ),
      StatefulShellRoute(
        builder: (_, __, shell) => MainShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) =>
            AnimatedBranchContainer(
                currentIndex: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/favorites',
                builder: (_, __) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/chats',
                builder: (_, s) =>
                    ChatsScreen(initialTab: s.uri.queryParameters['tab'])),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => ProductDetailsScreen(
          productId: s.pathParameters['id']!,
          initial: s.extra is Product ? s.extra as Product : null,
        ),
        routes: [
          GoRoute(
            path: 'comments',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, s) =>
                CommentsScreen(productId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: rootNavigatorKey,
        // extra: Product — «создать похожее» на его основе.
        pageBuilder: (_, s) =>
            _modalPage(s, CreateProductScreen(template: s.extra as Product?)),
      ),
      GoRoute(
        path: '/edit/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, s) =>
            _modalPage(s, CreateProductScreen(initial: s.extra as Product?)),
      ),
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => ChatScreen(
            chatId: s.pathParameters['chatId']!, peer: s.extra as User?),
      ),
      GoRoute(
        path: '/user/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => UserProfileScreen(
            userId: s.pathParameters['id']!, initial: s.extra as User?),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/store/manage',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const StoreManageScreen(),
      ),
      GoRoute(
        path: '/store/section/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) =>
            SectionEditorScreen(sectionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/store/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) =>
            StorefrontScreen(userId: s.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/cart',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CartScreen(),
      ),
      GoRoute(
        path: '/seller',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SellerDashboardScreen(),
      ),
    ],
  );
});
