import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaderboardType { allTime, weekly, monthly, attribute }

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String userName;
  final String tier;
  final int rating;
  final int wins;
  final int losses;
  final String? tierEmoji;
  final DateTime updatedAt;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.tier,
    required this.rating,
    required this.wins,
    required this.losses,
    this.tierEmoji,
    required this.updatedAt,
  });

  double get winRate => (wins + losses) == 0 ? 0 : wins / (wins + losses);

  Map<String, dynamic> toMap() => {
    'rank': rank,
    'userId': userId,
    'userName': userName,
    'tier': tier,
    'rating': rating,
    'wins': wins,
    'losses': losses,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {int rank = 0}) {
    return LeaderboardEntry(
      rank: rank,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      tier: map['tier'] ?? 'bronze',
      rating: map['rating'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AttributeLeaderboard {
  final String attribute; // 'joy', 'anger', 'sadness'
  final List<LeaderboardEntry> entries;
  final DateTime updatedAt;

  AttributeLeaderboard({
    required this.attribute,
    required this.entries,
    required this.updatedAt,
  });

  String get attributeEmoji => switch (attribute) {
    'joy' => '☀️',
    'anger' => '🔥',
    'sadness' => '🌙',
    _ => '⭐',
  };

  Map<String, dynamic> toMap() => {
    'attribute': attribute,
    'entries': entries.map((e) => e.toMap()).toList(),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory AttributeLeaderboard.fromMap(Map<String, dynamic> map) {
    final entriesData = (map['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final entries = entriesData.asMap().entries.map((e) {
      return LeaderboardEntry.fromMap(e.value, rank: e.key + 1);
    }).toList();

    return AttributeLeaderboard(
      attribute: map['attribute'] ?? 'joy',
      entries: entries,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DailyLeaderboard {
  final DateTime day;
  final List<LeaderboardEntry> entries;

  DailyLeaderboard({required this.day, required this.entries});
}

class WeeklyLeaderboard {
  final int weekNumber;
  final int year;
  final List<LeaderboardEntry> entries;
  final DateTime weekStart;
  final DateTime weekEnd;

  WeeklyLeaderboard({
    required this.weekNumber,
    required this.year,
    required this.entries,
    required this.weekStart,
    required this.weekEnd,
  });

  Map<String, dynamic> toMap() => {
    'weekNumber': weekNumber,
    'year': year,
    'entries': entries.map((e) => e.toMap()).toList(),
    'weekStart': Timestamp.fromDate(weekStart),
    'weekEnd': Timestamp.fromDate(weekEnd),
  };

  factory WeeklyLeaderboard.fromMap(Map<String, dynamic> map) {
    final entriesData = (map['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final entries = entriesData.asMap().entries.map((e) {
      return LeaderboardEntry.fromMap(e.value, rank: e.key + 1);
    }).toList();

    return WeeklyLeaderboard(
      weekNumber: map['weekNumber'] ?? 1,
      year: map['year'] ?? DateTime.now().year,
      entries: entries,
      weekStart: (map['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weekEnd: (map['weekEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class MonthlyLeaderboard {
  final int month;
  final int year;
  final List<LeaderboardEntry> entries;
  final DateTime updatedAt;

  MonthlyLeaderboard({
    required this.month,
    required this.year,
    required this.entries,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'month': month,
    'year': year,
    'entries': entries.map((e) => e.toMap()).toList(),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory MonthlyLeaderboard.fromMap(Map<String, dynamic> map) {
    final entriesData = (map['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final entries = entriesData.asMap().entries.map((e) {
      return LeaderboardEntry.fromMap(e.value, rank: e.key + 1);
    }).toList();

    return MonthlyLeaderboard(
      month: map['month'] ?? DateTime.now().month,
      year: map['year'] ?? DateTime.now().year,
      entries: entries,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
