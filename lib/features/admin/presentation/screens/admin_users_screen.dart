// lib/features/admin/presentation/screens/admin_users_screen.dart
// Admin User Management Screen - Allows administrators to manage platform users (view, add, edit, delete)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // Search functionality controllers and state variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  // User form controllers for add/edit operations
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = 'user';  // Default role for new users
  String? _editingUserId;          // Track which user is being edited (null means add mode)

  @override
  void initState() {
    super.initState();
    _checkUsersCollection(); // Verify users collection exists on screen load
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Check if users collection exists and has data, show appropriate error/empty state
  Future<void> _checkUsersCollection() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('No users found in collection');
        setState(() => _errorMessage = 'No users found. Click + to add your first user.');
      } else {
        print('Users collection exists with ${snapshot.docs.length}+ documents');
        setState(() => _errorMessage = null);
      }
    } catch (e) {
      print('Error checking users collection: $e');
      setState(() => _errorMessage = 'Error connecting to Firestore: $e');
    }
  }

  // Add new user to Firestore with form data
  Future<void> _addUser() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // Validate required fields
    if (firstName.isEmpty || email.isEmpty) {
      _showSnackBar('First name and email are required', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create a new user document with auto-generated ID
      final userRef = FirebaseFirestore.instance.collection('users').doc();

      await userRef.set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(), // Automatic timestamp
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true, // Default active status
      });

      _clearForm();
      _showSnackBar('User added successfully');
      if (mounted) Navigator.pop(context); // Close modal after success
    } catch (e) {
      _showSnackBar('Error adding user: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update existing user information in Firestore
  Future<void> _updateUser(String userId) async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // Validate required fields
    if (firstName.isEmpty || email.isEmpty) {
      _showSnackBar('First name and email are required', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': _selectedRole,
        'updatedAt': FieldValue.serverTimestamp(), // Update timestamp
      });

      _clearForm();
      _showSnackBar('User updated successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error updating user: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Delete user with confirmation dialog to prevent accidental deletion
  Future<void> _deleteUser(String userId, String userName) async {
    // Show confirmation dialog before deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete User',
          style: TextStyle(color: Color(0xFF3A2214), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$userName"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF8B7355)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B7355))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      _showSnackBar('User deleted successfully');
    } catch (e) {
      _showSnackBar('Error deleting user: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show modal bottom sheet for adding/editing users
  void _showUserForm({Map<String, dynamic>? userData, String? userId}) {
    _editingUserId = userId;

    // Populate form fields if editing existing user
    if (userData != null) {
      _firstNameController.text = userData['firstName']?.toString() ?? '';
      _lastNameController.text = userData['lastName']?.toString() ?? '';
      _emailController.text = userData['email']?.toString() ?? '';
      _phoneController.text = userData['phone']?.toString() ?? '';
      _selectedRole = userData['role']?.toString() ?? 'user';
    } else {
      _clearForm(); // Clear form for adding new user
    }

    final isEditing = userId != null;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to adjust for keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator handle at top of modal
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Modal title (Add or Edit based on mode)
                  Text(
                    isEditing ? 'Edit User' : 'Add New User',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Form fields
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(isDarkMode),
                  const SizedBox(height: 24),
                  // Action buttons (Cancel & Save)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8B7355),
                            side: const BorderSide(color: Color(0xFFE2C9A4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            if (isEditing) {
                              await _updateUser(userId!);
                            } else {
                              await _addUser();
                            }
                            if (mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCB6B2E),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            isEditing ? 'Update' : 'Add',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Build styled text input field with icon
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDarkMode,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFCB6B2E), size: 20),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFCF7E8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCB6B2E), width: 2),
        ),
      ),
    );
  }

  // Build role selection dropdown (User, Admin, Driver)
  Widget _buildRoleDropdown(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFCF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFCB6B2E)),
          style: TextStyle(
            color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
            fontSize: 16,
          ),
          items: const [
            DropdownMenuItem(value: 'user', child: Text('User')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'driver', child: Text('Driver')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedRole = value);
            }
          },
        ),
      ),
    );
  }

  // Clear all form fields after add/edit operation
  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _selectedRole = 'user';
    _editingUserId = null;
  }

  // Display floating snackbar notification for user feedback
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Format timestamp for display in human-readable format
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    // Return appropriate format based on age
    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  // Get color code based on user role for badge styling
  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFF9C27B0);   // Purple for admin
      case 'driver': return const Color(0xFF2196F3); // Blue for driver
      case 'user': return const Color(0xFF4CAF50);   // Green for regular user
      default: return const Color(0xFFCB6B2E);       // Orange default
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors based on dark/light mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF);
    final textColor = isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: textColor),
        ),
        title: Text(
          'User Management',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add new user button
          IconButton(
            onPressed: () => _showUserForm(),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFCB6B2E), size: 28),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar for filtering users by name or email
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: const Color(0xFFCB6B2E), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  // Clear search button (only visible when search has text)
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close, color: Color(0xFFCB6B2E), size: 18),
                    ),
                ],
              ),
            ),
          ),
          // Users List - Real-time stream from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // No orderBy to avoid index issues - Firestore default order is fine
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                print('Snapshot connection state: ${snapshot.connectionState}');
                print('Snapshot has data: ${snapshot.hasData}');
                print('Snapshot has error: ${snapshot.hasError}');

                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFCB6B2E)),
                        SizedBox(height: 16),
                        Text('Loading users...'),
                      ],
                    ),
                  );
                }

                // Error state with retry button
                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading users: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFF8B7355)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkUsersCollection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCB6B2E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!.docs;
                print('Number of users found: ${users.length}');

                // Empty state - no users exist
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: const Color(0xFFCB6B2E).withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first user',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Apply search filter by first name, last name, or email
                final filteredUsers = _searchQuery.isEmpty
                    ? users
                    : users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final firstName = data['firstName']?.toString().toLowerCase() ?? '';
                  final lastName = data['lastName']?.toString().toLowerCase() ?? '';
                  final email = data['email']?.toString().toLowerCase() ?? '';
                  return firstName.contains(_searchQuery) ||
                      lastName.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

                // No search results found
                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: const Color(0xFFCB6B2E).withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Render user list
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final doc = filteredUsers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    final firstName = data['firstName']?.toString() ?? 'Unknown';
                    final lastName = data['lastName']?.toString() ?? '';
                    final email = data['email']?.toString() ?? 'No email';
                    final phone = data['phone']?.toString() ?? '';
                    final role = data['role']?.toString() ?? 'user';
                    final createdAt = data['createdAt'];
                    final isActive = data['isActive'] ?? true;

                    // Individual user card widget
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4).withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showUserForm(userData: data, userId: userId),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Avatar with user's first initial
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFCB6B2E), Color(0xFFF0A73A)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Center(
                                    child: Text(
                                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // User Information Section
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // User name and role badge row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$firstName $lastName',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(role).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              role.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _getRoleColor(role),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Email row
                                      Row(
                                        children: [
                                          const Icon(Icons.email_outlined, size: 12, color: Color(0xFFCB6B2E)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Phone number row (if available)
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined, size: 12, color: Color(0xFFCB6B2E)),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      // Join date and active status row
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 10, color: Color(0xFFCB6B2E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Joined: ${_formatDate(createdAt)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDarkMode ? const Color(0xFFBEBEBE).withOpacity(0.7) : const Color(0xFF8B7355).withOpacity(0.8),
                                            ),
                                          ),
                                          if (!isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'INACTIVE',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Action Buttons (Edit & Delete)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showUserForm(userData: data, userId: userId),
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFCB6B2E), size: 20),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(height: 4),
                                    IconButton(
                                      onPressed: () => _deleteUser(userId, '$firstName $lastName'),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}