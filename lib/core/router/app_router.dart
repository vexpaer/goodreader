import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_detail/book_detail_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/reader/reader_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
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
