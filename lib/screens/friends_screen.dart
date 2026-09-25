import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:card_rivals/providers/friends_provider.dart';
import 'package:card_rivals/models/friend.dart';
import 'package:card_rivals/models/friend_request.dart';
import 'friend_detail_screen.dart';
import 'friend_search_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    return userId.when(
      data: (id) => _buildFriendsUI(context, id),
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => Scaffold(
        body: SafeArea(child: Center(child: Text('Error: $err'))),
      ),
    );
  }

  Widget _buildFriendsUI(BuildContext context, String userId) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.person_add)),
            Tab(text: 'Search', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsList(context, userId),
            _buildFriendRequests(context, userId),
            const FriendSearchScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, String userId) {
    final friendsAsync = ref.watch(friendsListProvider(userId));

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for players and add them as friends',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort friends by rating (descending)
        friends.sort((a, b) => b.friendRating.compareTo(a.friendRating));

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return FriendListTile(
              friend: friend,
              userId: userId,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FriendDetailScreen(
                      friendId: friend.friendId,
                      friendName: friend.friendName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildFriendRequests(BuildContext context, String userId) {
    final requestsAsync = ref.watch(incomingFriendRequestsProvider(userId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return FriendRequestTile(
              request: request,
              userId: userId,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

/// Tile for displaying a friend in the friends list
class FriendListTile extends ConsumerWidget {
  final Friend friend;
  final String userId;
  final VoidCallback? onTap;

  const FriendListTile({
    Key? key,
    required this.friend,
    required this.userId,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Text(
          friend.friendName.isNotEmpty
              ? friend.friendName[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(friend.customAlias ?? friend.friendName),
      subtitle: Row(
        children: [
          Chip(
            label: Text(
              'Tier ${friend.friendTier}',
              style: const TextStyle(fontSize: 12),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Text(
            'Rating: ${friend.friendRating.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: () {
              // Implement view stats
            },
            child: const Text('View Stats'),
          ),
          PopupMenuItem(
            onTap: () {
              // Implement edit alias
              _showEditAliasDialog(context, ref);
            },
            child: const Text('Edit Alias'),
          ),
          PopupMenuItem(
            onTap: () async {
              await removeFriend(userId: userId, friendId: friend.friendId);
              ref.invalidate(friendsListProvider(userId));
            },
            child: const Text('Remove Friend'),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showEditAliasDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: friend.customAlias ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Alias'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter a nickname for this friend',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await updateFriendAlias(
                userId: userId,
                friendId: friend.friendId,
                alias: controller.text.isEmpty ? null : controller.text,
              );
              ref.invalidate(friendsListProvider(userId));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Tile for displaying a friend request
class FriendRequestTile extends ConsumerWidget {
  final FriendRequest request;
  final String userId;

  const FriendRequestTile({
    Key? key,
    required this.request,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        child: Text(
          request.senderName.isNotEmpty
              ? request.senderName[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(request.senderName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating: ${request.senderRating.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (request.message != null) ...[
            const SizedBox(height: 4),
            Text(
              'Message: ${request.message}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Expires in ${request.daysRemaining} days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await rejectFriendRequest(
                  requestId: request.id,
                  userId: userId,
                );
                ref.invalidate(incomingFriendRequestsProvider(userId));
              },
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                await acceptFriendRequest(
                  requestId: request.id,
                  userId: userId,
                  friendId: request.senderId,
                  friendName: request.senderName,
                  friendRating: request.senderRating,
                  friendTier: 1, // Will be fetched from Cloud Function
                  senderName: 'Current User', // Should be fetched
                  senderRating: 1000, // Should be fetched
                );
                ref.invalidate(incomingFriendRequestsProvider(userId));
                ref.invalidate(friendsListProvider(userId));
              },
            ),
          ],
        ),
      ),
    );
  }
}
