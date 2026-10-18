import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_detail/book_detail_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/reader/reader_page.dart';
import '../../features/settings/update_page.dart';
import '../../features/share/border_designer_page.dart';
import '../../features/ai/ai_chat_page.dart';
import '../../features/booksource/booksource_editor_page.dart';
import '../../features/booksource/booksource_page.dart';
import '../../features/booksource/booksource_search_page.dart';
import '../../features/services/service_providers_page.dart';
import '../../features/sync/sync_page.dart';
import '../../features/transfer/wifi_transfer_page.dart';
import '../../features/share/border_gallery_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
    ),
    GoRoute(
      path: '/update',
      builder: (context, state) => const UpdatePage(),
    ),
    GoRoute(
      path: '/sources',
      builder: (context, state) => const BookSourcePage(),
    ),
    GoRoute(
      path: '/sources/edit',
      builder: (context, state) => const BookSourceEditorPage(),
    ),
    GoRoute(
      path: '/sources/edit/:id',
      builder: (context, state) => BookSourceEditorPage(
        sourceId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/sources/search/:id',
      builder: (context, state) => BookSourceSearchPage(
        sourceId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const SyncPage(),
    ),
    GoRoute(
      path: '/transfer',
      builder: (context, state) => const WifiTransferPage(),
    ),
    GoRoute(
      path: '/borders',
      builder: (context, state) => const BorderGalleryPage(),
    ),
    GoRoute(
      path: '/services',
      builder: (context, state) => const ServiceProvidersPage(),
    ),
    GoRoute(
      path: '/ai',
      builder: (context, state) => const AiChatPage(),
    ),
    GoRoute(
      path: '/ai/:id',
      builder: (context, state) => AiChatPage(
        bookId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/borders/:id',
      builder: (context, state) => BorderDesignerPage(
        assetId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/book/:id',
      builder: (context, state) => BookDetailPage(
        bookId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/reader/:id',
      builder: (context, state) => ReaderPage(
        bookId: state.pathParameters['id']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('页面不存在')),
    body: Center(child: Text(state.error?.toString() ?? '未知错误')),
  ),
);
