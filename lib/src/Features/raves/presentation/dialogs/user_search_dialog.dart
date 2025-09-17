import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'dart:async';
import '../../../../Data/models/users.dart';
import '../../../../Data/services/localization_service.dart';
import '../../../../Theme/palette.dart';

class UserSearchDialog extends StatefulWidget {
  final UserType userType;
  final List<AppUser> selectedUsers;
  final Function(List<AppUser>) onUsersSelected;

  const UserSearchDialog({
    super.key,
    required this.userType,
    required this.selectedUsers,
    required this.onUsersSelected,
  });

  @override
  State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  List<AppUser> _tempSelectedUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tempSelectedUsers = List.from(widget.selectedUsers);
    _debouncedSearch(''); // Load initial users with debounce
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF333333), width: 1),
      ),
      title: Text(
        widget.userType == UserType.dj ? 'Select DJs' : 'Select Collaborators',
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 16),
            _buildSelectedUsersChips(),
            const SizedBox(height: 16),
            Expanded(child: _buildUsersList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.cancel.getString(context),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onUsersSelected(_tempSelectedUsers);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            AppLocale.done.getString(context),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
        _debouncedSearch(value);
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText:
            widget.userType == UserType.dj
                ? AppLocale.searchDJs.getString(context)
                : AppLocale.searchBookers.getString(context),
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _debouncedSearch('');
                  },
                )
                : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildSelectedUsersChips() {
    if (_tempSelectedUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            _tempSelectedUsers.map((user) {
              String name = '';
              if (user is DJ) name = user.name;
              if (user is Booker) name = user.name;

              return Chip(
                label: Text(
                  name,
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                ),
                backgroundColor: const Color(0xFFD4AF37),
                deleteIcon: const Icon(
                  Icons.close,
                  color: Colors.black,
                  size: 16,
                ),
                onDeleted: () {
                  setState(() {
                    _tempSelectedUsers.remove(user);
                  });
                },
              );
            }).toList(),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.userType == UserType.dj ? Icons.headset : Icons.people,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? (widget.userType == UserType.dj
                      ? 'No DJs found'
                      : 'No Bookers found')
                  : 'No users match your search',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSelected = _tempSelectedUsers.any((u) => u.id == user.id);

        return _buildUserTile(user, isSelected);
      },
    );
  }

  Widget _buildUserTile(AppUser user, bool isSelected) {
    String name = '';
    String subtitle = '';
    String? profileImageUrl;

    if (user is DJ) {
      name = user.name;
      subtitle = user.genres.isNotEmpty ? user.genres.take(2).join(', ') : 'DJ';
      profileImageUrl = user.avatarImageUrl;
    } else if (user is Booker) {
      name = user.name;
      subtitle = user.category.isNotEmpty ? user.category : 'Booker';
      profileImageUrl = user.avatarImageUrl;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFFD4AF37).o(0.1)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF333333),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF333333),
          backgroundImage:
              profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : null,
          child:
              profileImageUrl == null || profileImageUrl.isEmpty
                  ? Icon(
                    widget.userType == UserType.dj
                        ? Icons.headset
                        : Icons.person,
                    color: const Color(0xFFD4AF37),
                    size: 20,
                  )
                  : null,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing:
            isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37))
                : const Icon(Icons.add_circle_outline, color: Colors.white54),
        onTap: () {
          setState(() {
            if (isSelected) {
              _tempSelectedUsers.removeWhere((u) => u.id == user.id);
            } else {
              _tempSelectedUsers.add(user);
            }
          });
        },
      ),
    );
  }

  void _debouncedSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Query the 'users' collection and filter by user type
      Query firestoreQuery = FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: widget.userType.name)
          .limit(50); // Increase limit to get more results

      final querySnapshot = await firestoreQuery.get();

      List<AppUser> users = [];
      for (var doc in querySnapshot.docs) {
        try {
          // Skip current user
          if (doc.id == currentUser.uid) continue;

          final userData = doc.data() as Map<String, dynamic>;

          final user = AppUser.fromJson(doc.id, userData);
          users.add(user);
        } catch (e) {
          continue;
        }
      }

      // Client-side filtering for search query
      if (query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        users =
            users.where((user) {
              String name = '';
              if (user is DJ) name = user.name;
              if (user is Booker) name = user.name;
              return name.toLowerCase().contains(queryLower);
            }).toList();
      }

      if (mounted) {
        setState(() {
          _searchResults = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }
}
