import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:card_rivals/providers/friends_provider.dart';
import 'package:card_rivals/models/player_public_profile.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendId;
  final String friendName;

  const FriendDetailScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerPublicProfileProvider(friendId));

    return Scaffold(
      appBar: AppBar(
        title: Text(friendName),
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => _buildProfileContent(context, ref, profile),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    PlayerPublicProfile profile,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and basic info
          _buildProfileHeader(context, profile),

          const Divider(),

          // Rating and tier info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildRatingCard(context, profile),
          ),

          const Divider(),

          // Battle stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildBattleStats(context, profile),
          ),

          const Divider(),

          // Achievements/Badges
          if (profile.badges.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBadges(context, profile),
            ),
            const Divider(),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildActionButtons(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    PlayerPublicProfile profile,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue[100],
                child: Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    if (profile.bio != null)
                      Text(
                        profile.bio!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    if (profile.region != null)
                      Text(
                        'Region: ${profile.region}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(
                  profile.tierDescription,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Color(int.parse(
                  profile.tierColor.replaceFirst('#', '0xff'),
                )),
              ),
              if (profile.isOnline)
                Chip(
                  label: const Text('Online'),
                  backgroundColor: Colors.green[300],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(
    BuildContext context,
    PlayerPublicProfile profile,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rating & Rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  'ELO Rating',
                  profile.rating.toStringAsFixed(0),
                ),
                _buildStatColumn(
                  context,
                  'Tier',
                  '${profile.tier}/10',
                ),
                _buildStatColumn(
                  context,
                  'Friends',
                  profile.friendCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleStats(
    BuildContext context,
    PlayerPublicProfile profile,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battle Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  'Total Battles',
                  profile.battleCount.toString(),
                ),
                _buildStatColumn(
                  context,
                  'Wins',
                  profile.wins.toString(),
                ),
                _buildStatColumn(
                  context,
                  'Win Rate',
                  '${profile.winRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  'Current Streak',
                  profile.currentStreak.toString(),
                ),
                _buildStatColumn(
                  context,
                  'Best Streak',
                  profile.bestStreak.toString(),
                ),
                if (profile.lastBattleAt != null)
                  _buildStatColumn(
                    context,
                    'Last Battle',
                    _formatTime(profile.lastBattleAt!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(
    BuildContext context,
    PlayerPublicProfile profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: profile.badges
              .map((badge) => Chip(
                    label: Text(badge),
                    avatar: const Icon(Icons.star, size: 16),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('View battle history')),
            );
          },
          child: const Text('View Battle History'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Challenge coming soon')),
            );
          },
          child: const Text('Challenge to Battle'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            // Remove friend
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Remove Friend'),
        ),
      ],
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return dateTime.toString().split(' ')[0];
    }
  }
}
