import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../state/providers.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(statsControllerProvider);
    ref.watch(booksControllerProvider);

    final controller = ref.read(statsControllerProvider);
    final settings = ref.read(settingsControllerProvider).app;

    final today = controller.today();
    final week = controller.lastDays(7);
    final all = controller.allTime();

    final goalSeconds = settings.dailyGoalMinutes * 60;
    final goalRatio =
        goalSeconds == 0 ? 0.0 : (today.totalSeconds / goalSeconds).clamp(0.0, 1.0);

    final ranking = all.byBook.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              _MetricCard(
                label: '今日阅读',
                value: _humanDuration(today.totalSeconds),
                icon: Icons.today,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                label: '连续天数',
                value: '${all.streakDays} 天',
                icon: Icons.local_fire_department,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricCard(
                label: '累计时长',
                value: _humanDuration(all.totalSeconds),
                icon: Icons.schedule,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                label: '累计字数',
                value: _humanCount(all.totalChars),
                icon: Icons.text_fields,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            title: '今日目标',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: goalRatio,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_humanDuration(today.totalSeconds)} / ${settings.dailyGoalMinutes} 分钟'
                  '（${(goalRatio * 100).toStringAsFixed(0)}%）',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '已读 ${_humanCount(today.totalChars)} 字 / 目标 ${settings.dailyGoalChars} 字',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '最近 7 天',
            child: SizedBox(
              height: 170,
              child: _WeekChart(byDay: week.byDay),
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '阅读热力图（近 12 周）',
            child: _Heatmap(byDay: all.byDay),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '阅读时长排行',
            child: ranking.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('还没有阅读记录'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < ranking.length && i < 10; i++)
                        _RankRow(
                          index: i,
                          book: ref
                              .read(bookRepositoryProvider)
                              .byId(ranking[i].key),
                          seconds: ranking[i].value,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.byDay});

  final Map<String, int> byDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i)),
    );
    final values = days.map((d) => (byDay[_key(d)] ?? 0) / 60).toList();
    final maxY = values.fold<double>(1, (p, v) => v > p ? v : p) * 1.25;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${days[i].month}/${days[i].day}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.byDay});

  final Map<String, int> byDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Align the grid so the last column is the current week.
    const totalDays = 12 * 7;
    final start = today.subtract(Duration(days: totalDays - 1));
    final cells = List.generate(
      totalDays,
      (i) => start.add(Duration(days: i)),
    );

    final maxSeconds = byDay.values.fold<int>(1, (p, v) => v > p ? v : p);

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: cells.map((d) {
        final seconds = byDay[_WeekChart._key(d)] ?? 0;
        final intensity = (seconds / maxSeconds).clamp(0.0, 1.0);
        final color = seconds == 0
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Color.lerp(
                Theme.of(context).colorScheme.primary.withOpacity(0.25),
                Theme.of(context).colorScheme.primary,
                intensity,
              );
        return Tooltip(
          message:
              '${d.month}/${d.day} · ${seconds ~/ 60} 分钟',
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.index,
    required this.book,
    required this.seconds,
  });

  final int index;
  final Book? book;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              book?.title ?? '已删除的书籍',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(_humanDuration(seconds), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

String _humanDuration(int seconds) {
  if (seconds <= 0) return '0 分钟';
  if (seconds < 60) return '$seconds 秒';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  return '$hours 小时 ${minutes % 60} 分';
}

String _humanCount(int count) {
  if (count <= 0) return '0 字';
  if (count < 10000) return '$count 字';
  return '${(count / 10000).toStringAsFixed(1)} 万字';
}
