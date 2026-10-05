import 'package:hooks_riverpod/legacy.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final int bonusPoints;
  final int dailyBonus;
  final String tier;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.bonusPoints,
    required this.dailyBonus,
    required this.tier,
  });
}

// Sample user provider
final userProvider = StateProvider<UserProfile?>((ref) {
  return UserProfile(
    uid: 'sample_uid',
    displayName: 'Sample User',
    bonusPoints: 157,
    dailyBonus: 12,
    tier: 'bronze',
  );
});
