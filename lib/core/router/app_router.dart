import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_detail/book_detail_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/reader/reader_page.dart';
import '../../features/settings/update_page.dart';
import '../../features/share/border_designer_page.dart';
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
      path: '/borders',
      builder: (context, state) => const BorderGalleryPage(),
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
