import 'package:flutter/material.dart';

import '../models/friend_profile.dart';
import '../services/api_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.apiService,
    required this.onError,
  });

  final ApiService apiService;
  final void Function(String message) onError;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  FriendsOverview? _overview;
  bool _loading = true;
  bool _sending = false;
  int? _acceptingId;
  final TextEditingController _usernameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    final response = await widget.apiService.fetchFriends();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _overview = response.data;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      widget.onError(response.error ?? "Failed to load friends");
    }
  }

  Future<void> _sendRequest() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;
    setState(() => _sending = true);
    final response = await widget.apiService.sendFriendRequest(username);
    if (!mounted) return;
    setState(() => _sending = false);
    if (response.isSuccess) {
      _usernameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request sent to $username")),
      );
      _loadFriends();
    } else {
      widget.onError(response.error ?? "Could not send request");
    }
  }

  Future<void> _acceptRequest(int requestId) async {
    setState(() => _acceptingId = requestId);
    final response = await widget.apiService.acceptFriendRequest(requestId);
    if (!mounted) return;
    setState(() => _acceptingId = null);
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend request accepted")),
      );
      _loadFriends();
    } else {
      widget.onError(response.error ?? "Could not accept request");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final overview = _overview;
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _addFriendCard(),
          const SizedBox(height: 14),
          if (overview != null && overview.incoming.isNotEmpty) ...[
            _sectionTitle("Requests to accept"),
            const SizedBox(height: 8),
            ...overview.incoming.map(_incomingCard),
            const SizedBox(height: 14),
          ],
          if (overview != null && overview.outgoing.isNotEmpty) ...[
            _sectionTitle("Sent requests"),
            const SizedBox(height: 8),
            ...overview.outgoing.map(_outgoingChip),
            const SizedBox(height: 14),
          ],
          _sectionTitle("Friends"),
          const SizedBox(height: 8),
          if (overview == null || overview.friends.isEmpty) _emptyStateCard(),
          if (overview != null)
            ...overview.friends.map((friend) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _friendCard(friend),
                )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }

  Widget _addFriendCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Add a friend by username",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: _sending ? null : _sendRequest,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Send"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              hintText: "@username",
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            onSubmitted: (_) => _sendRequest(),
          ),
        ],
      ),
    );
  }

  Widget _incomingCard(FriendRequestEntry entry) {
    final isAccepting = _acceptingId == entry.requestId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.teal.withValues(alpha: 0.12),
            child: Text(
              entry.username.isNotEmpty ? entry.username[0].toUpperCase() : "?",
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  "wants to connect",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isAccepting ? null : () => _acceptRequest(entry.requestId),
            child: isAccepting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Accept"),
          ),
        ],
      ),
    );
  }

  Widget _outgoingChip(FriendRequestEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Waiting on ${entry.username}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            entry.status,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _friendCard(FriendProfile friend) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: Center(
              child: Text(
                friend.username.isNotEmpty ? friend.username[0].toUpperCase() : "?",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pet stage: ${friend.petStage}",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statPill(Icons.star_rounded, "Level ${friend.petLevel}"),
                    const SizedBox(width: 8),
                    _statPill(Icons.bolt_rounded, "${friend.petXp} XP"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline_rounded, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text(
                "No friends yet",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Send a request to compare pets and levels together.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
