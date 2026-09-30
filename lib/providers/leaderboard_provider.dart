import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/leaderboard.dart';
import '../services/functions_service.dart';
import 'game_state_provider.dart';

// ランキング一覧は本人以外のusersドキュメントを直接読めない（firestore.rules）ため、
// getPeriodLeaderboard Cloud Function（Admin SDK経由）に集計を任せる。
// 以前はここに固定5人のダミーデータを返すStateProviderが置かれていた。

List<LeaderboardEntry> _entriesFromResponse(Map<String, dynamic> data) {
  final list = (data['leaderboard'] as List?) ?? const [];
  final now = DateTime.now();
  return list.map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final rating = (m['rating'] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      userId: m['userId'] as String? ?? '',
      userName: m['userName'] as String? ?? 'Unknown',
      tier: PlayerRank.tierForRating(rating),
      rating: rating,
      wins: (m['wins'] as num?)?.toInt() ?? 0,
      losses: (m['losses'] as num?)?.toInt() ?? 0,
      updatedAt: now,
    );
  }).toList();
}

// オールタイムランキング（ELO順）
final allTimeLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final data = await FunctionsService.getPeriodLeaderboard(periodType: 'allTime');
  return _entriesFromResponse(data);
});

// 日次ランキング
final dailyLeaderboardProvider = FutureProvider<DailyLeaderboard?>((ref) async {
  final data = await FunctionsService.getPeriodLeaderboard(periodType: 'daily');
  return DailyLeaderboard(day: DateTime.now(), entries: _entriesFromResponse(data));
});

// 週間ランキング
final weeklyLeaderboardProvider = FutureProvider<WeeklyLeaderboard?>((ref) async {
  final data = await FunctionsService.getPeriodLeaderboard(periodType: 'weekly');
  final now = DateTime.now();
  final firstDayOfYear = DateTime(now.year, 1, 1);
  final weekNumber = (now.difference(firstDayOfYear).inDays / 7).ceil();
  return WeeklyLeaderboard(
    weekNumber: weekNumber,
    year: now.year,
    entries: _entriesFromResponse(data),
    weekStart: now.subtract(Duration(days: now.weekday - 1)),
    weekEnd: now.add(Duration(days: 7 - now.weekday)),
  );
});

// 月間ランキング
final monthlyLeaderboardProvider = FutureProvider<MonthlyLeaderboard?>((ref) async {
  final data = await FunctionsService.getPeriodLeaderboard(periodType: 'monthly');
  final now = DateTime.now();
  return MonthlyLeaderboard(
    month: now.month,
    year: now.year,
    entries: _entriesFromResponse(data),
    updatedAt: now,
  );
});
