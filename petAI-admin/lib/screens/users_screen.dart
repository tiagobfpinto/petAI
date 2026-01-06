import "package:flutter/material.dart";

import "../models/user_summary.dart";
import "../services/admin_api_service.dart";
import "../widgets/user_detail_panel.dart";

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final AdminApiService api;
  final VoidCallback onLogout;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  List<UserSummary> _users = const [];
  UserSummary? _selectedUser;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.api.fetchUsers(query: query, limit: 100);
    if (!mounted) return;
    if (result.isSuccess) {
      final users = result.data ?? [];
      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
        _loading = false;
      });
      return;
    }
    if (result.statusCode == 401) {
      widget.onLogout();
      return;
    }
    setState(() {
      _error = result.error ?? "Failed to load users.";
      _loading = false;
    });
  }

  void _updateUser(UserSummary updated) {
    final updatedList =
        _users.map((user) => user.id == updated.id ? updated : user).toList();
    setState(() {
      _users = updatedList;
      _selectedUser = updated;
    });
  }

  void _openDetail(UserSummary user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _UserDetailScreen(
              user: user,
              api: widget.api,
              onUserUpdated: (updated) {
                _updateUser(updated);
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("petAI Admin"),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadUsers(),
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
          TextButton(
            onPressed: _loading ? null : widget.onLogout,
            child: const Text("Logout"),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _loadUsers(query: value),
                    decoration: const InputDecoration(
                      labelText: "Search by username or email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed:
                      _loading
                          ? null
                          : () => _loadUsers(query: _searchController.text),
                  icon: const Icon(Icons.search),
                  label: const Text("Search"),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 900) {
                          return _buildListView(onTap: _openDetail);
                        }
                        return Row(
                          children: [
                            SizedBox(
                              width: 360,
                              child: _buildListView(
                                onTap: (user) {
                                  setState(() {
                                    _selectedUser = user;
                                  });
                                },
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child:
                                  _selectedUser == null
                                      ? const Center(
                                        child: Text("Select a user"),
                                      )
                                      : UserDetailPanel(
                                        user: _selectedUser!,
                                        api: widget.api,
                                        onUserUpdated: _updateUser,
                                      ),
                            ),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView({required ValueChanged<UserSummary> onTap}) {
    if (_users.isEmpty) {
      return const Center(child: Text("No users found."));
    }
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _users[index];
        final title = user.username?.isNotEmpty == true
            ? user.username!
            : user.email?.isNotEmpty == true
            ? user.email!
            : "Guest #${user.id}";
        final subtitleParts = <String>[];
        if (user.email != null && user.email!.isNotEmpty) {
          subtitleParts.add(user.email!);
        }
        subtitleParts.add(user.isGuest ? "Guest" : "Registered");
        subtitleParts.add(user.isActive ? "Active" : "Inactive");
        return ListTile(
          selected: _selectedUser?.id == user.id,
          title: Text(title),
          subtitle: Text(subtitleParts.join(" • ")),
          trailing: Text("${user.coins} coins"),
          onTap: () => onTap(user),
        );
      },
    );
  }
}

class _UserDetailScreen extends StatelessWidget {
  const _UserDetailScreen({
    required this.user,
    required this.api,
    required this.onUserUpdated,
  });

  final UserSummary user;
  final AdminApiService api;
  final ValueChanged<UserSummary> onUserUpdated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User #${user.id}")),
      body: UserDetailPanel(
        user: user,
        api: api,
        onUserUpdated: (updated) {
          onUserUpdated(updated);
        },
      ),
    );
  }
}
