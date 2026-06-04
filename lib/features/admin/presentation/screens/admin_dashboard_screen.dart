// Admin Dashboard Screen - Main dashboard for admin panel and management features

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:culinary_coach_app/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:culinary_coach_app/features/admin/presentation/screens/admin_orders_drivers.dart';

class AdminDashboardScreen extends StatefulWidget {
  final bool isDarkMode;

  const AdminDashboardScreen({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // State variables for loading status and dashboard statistics
  bool _isLoading = true;
  DashboardStats _stats = DashboardStats.empty();

  @override
  void initState() {
    super.initState();
    _loadStats(); // Load dashboard statistics when screen initializes
  }

  // Load all statistics from Firestore collections
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // Fetch data from multiple Firestore collections simultaneously
      final ordersFuture = FirebaseFirestore.instance.collection('shop_orders').get();
      final recipesFuture = FirebaseFirestore.instance.collection('recipes').get();
      final ingredientsFuture = FirebaseFirestore.instance.collection('full_ingredients').get();
      final usersFuture = FirebaseFirestore.instance.collection('users').get();

      // Wait for all database queries to complete
      final results = await Future.wait([
        ordersFuture,
        recipesFuture,
        ingredientsFuture,
        usersFuture,
      ]);

      final orders = results[0] as QuerySnapshot;
      final recipes = results[1] as QuerySnapshot;
      final ingredients = results[2] as QuerySnapshot;
      final users = results[3] as QuerySnapshot;

      // Initialize counters for order status tracking
      int pending = 0, preparing = 0, outForDelivery = 0, delivered = 0, cancelled = 0;
      double revenue = 0;

      // Extract unique drivers from orders using a Set to avoid duplicates
      Set<String> uniqueDrivers = {};

      // Process each order to calculate statistics
      for (final doc in orders.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? 'pending';
        final total = (data['total'] as num?)?.toDouble() ?? 0;

        // Extract driver info from order if present
        if (data['driver'] != null) {
          final driverData = data['driver'] as Map<String, dynamic>;
          final driverName = driverData['name']?.toString();
          if (driverName != null && driverName.isNotEmpty) {
            uniqueDrivers.add(driverName); // Add to Set for unique driver count
          }
        }

        // Increment appropriate status counter
        switch (status) {
          case 'pending': pending++; break;
          case 'preparing': preparing++; break;
          case 'out_for_delivery': outForDelivery++; break;
          case 'delivered':
            delivered++;
            revenue += total; // Add to revenue only for delivered orders
            break;
          case 'cancelled': cancelled++; break;
        }
      }

      // Update state with calculated statistics
      setState(() {
        _stats = DashboardStats(
          totalOrders: orders.docs.length,
          totalRecipes: recipes.docs.length,
          totalIngredients: ingredients.docs.length,
          totalDrivers: uniqueDrivers.length, // Count of unique drivers from orders
          totalUsers: users.docs.length,
          pendingOrders: pending,
          preparingOrders: preparing,
          outForDeliveryOrders: outForDelivery,
          deliveredOrders: delivered,
          cancelledOrders: cancelled,
          totalRevenue: revenue,
          lastUpdated: DateTime.now(),
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      setState(() => _isLoading = false);
    }
  }

  // Navigation helper to push new screens
  void _navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats, // Pull to refresh functionality
      color: const Color(0xFFCB6B2E), // Brand orange color
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Welcome Section with gradient background
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Statistics Grid (4 stat cards)
            _buildStatsGrid(),
            const SizedBox(height: 24),

            // Quick Management Cards
            _buildManagementSection(),
            const SizedBox(height: 24),

            // Recent Orders Section (Unclickable display only)
            _RecentOrdersSection(isDarkMode: widget.isDarkMode),
          ],
        ),
      ),
    );
  }

  // Welcome section with user greeting and platform overview
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDarkMode
              ? [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)]
              : [const Color(0xFFCB6B2E), const Color(0xFFE8913A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your platform today.',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDarkMode ? Colors.white70 : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.analytics_rounded,
              size: 40,
              color: widget.isDarkMode ? Colors.white : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Statistics grid displaying key metrics (Total Orders, Users, Ingredients, Drivers)
  Widget _buildStatsGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        switch (index) {
          case 0: // Total Orders Card - Navigates to Order Driver Management
            return _StatCard(
              title: 'Total Orders',
              value: '${_stats.totalOrders}',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFFCB6B2E),
              isDarkMode: widget.isDarkMode,
              onTap: () => _navigateToScreen(const AdminOrdersDriversScreen()),
            );
          case 1: // Total Users Card - Navigates to User Management
            return _StatCard(
              title: 'Total Users',
              value: '${_stats.totalUsers}',
              icon: Icons.people_rounded,
              color: const Color(0xFF2196F3),
              isDarkMode: widget.isDarkMode,
              onTap: () => _navigateToScreen(const AdminUsersScreen()),
            );
          case 2: // Ingredients Card - Display only, not clickable
            return _StatCard(
              title: 'Ingredients',
              value: '${_stats.totalIngredients}',
              icon: Icons.grass_rounded,
              color: const Color(0xFF9C27B0),
              isDarkMode: widget.isDarkMode,
              onTap: null, // Make Ingredients unclickable
            );
          case 3: // Drivers Card - Display only, not clickable
            return _StatCard(
              title: 'Drivers',
              value: '${_stats.totalDrivers}',
              icon: Icons.delivery_dining_rounded,
              color: const Color(0xFF00BCD4),
              isDarkMode: widget.isDarkMode,
              onTap: null,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // Quick Management section with action cards for common admin tasks
  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: 2, // Only 2 cards: Manage Orders and Manage Users
          itemBuilder: (context, index) {
            final items = [
              {'title': 'Manage Orders', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFFCB6B2E), 'screen': const AdminOrdersDriversScreen()},
              {'title': 'Manage Users', 'icon': Icons.people_rounded, 'color': const Color(0xFF2196F3), 'screen': const AdminUsersScreen()},
            ];

            final item = items[index];
            return GestureDetector(
              onTap: () => _navigateToScreen(item['screen'] as Widget),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF232323) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Analytics item builder (utility method for displaying metrics)
  Widget _buildAnalyticsItem(String label, String value, String? percentage, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: widget.isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
            ),
          ),
          if (percentage != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                percentage,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Data model class for dashboard statistics
class DashboardStats {
  final int totalOrders;
  final int totalRecipes;
  final int totalIngredients;
  final int totalDrivers;
  final int totalUsers;
  final int pendingOrders;
  final int preparingOrders;
  final int outForDeliveryOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final DateTime lastUpdated;

  const DashboardStats({
    required this.totalOrders,
    required this.totalRecipes,
    required this.totalIngredients,
    required this.totalDrivers,
    required this.totalUsers,
    required this.pendingOrders,
    required this.preparingOrders,
    required this.outForDeliveryOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
    required this.lastUpdated,
  });

  // Factory method to create empty stats (useful for initial state)
  factory DashboardStats.empty() {
    return DashboardStats(
      totalOrders: 0,
      totalRecipes: 0,
      totalIngredients: 0,
      totalDrivers: 0,
      totalUsers: 0,
      pendingOrders: 0,
      preparingOrders: 0,
      outForDeliveryOrders: 0,
      deliveredOrders: 0,
      cancelledOrders: 0,
      totalRevenue: 0,
      lastUpdated: DateTime.now(),
    );
  }
}

// Reusable stat card widget for displaying metrics
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap, // Nullable onTap - if null, card is not clickable
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF232323) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? const Color(0xFF444444)
                  : const Color(0xFFE2C9A4).withOpacity(0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? const Color(0xFFBEBEBE)
                      : const Color(0xFF8B7355),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFFA0856A),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Recent Orders Section - Displays latest 5 orders (read-only, not clickable)
class _RecentOrdersSection extends StatelessWidget {
  final bool isDarkMode;

  const _RecentOrdersSection({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    // Get theme brightness from context for order cards
    final themeDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          'Recent Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
          ),
        ),
        const SizedBox(height: 4),
        // Section subtitle
        Text(
          'Latest customer orders',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
          ),
        ),
        const SizedBox(height: 16),
        // Stream builder for real-time order updates
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shop_orders')
              .orderBy('orderCreatedAtMillis', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFF8B7355)),
                    ),
                  ],
                ),
              );
            }

            final orders = snapshot.data?.docs ?? [];

            if (orders.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF232323) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Color(0xFFCB6B2E)),
                    SizedBox(height: 12),
                    Text(
                      'No orders yet',
                      style: TextStyle(color: Color(0xFF8B7355), fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Orders will appear here once customers place them',
                      style: TextStyle(color: Color(0xFF8B7355), fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;

                  // Return OrderCard without GestureDetector (unclickable)
                  // Pass isDarkMode from parent to ensure proper theming
                  return _OrderCard(
                    data: data,
                    orderId: order.id,
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// Individual order card widget for displaying order information
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final bool isDarkMode;

  const _OrderCard({
    required this.data,
    required this.orderId,
    required this.isDarkMode,
  });

  // Helper getters for order data
  String get orderNumber => data['orderId']?.toString() ?? orderId.substring(0, 8);
  String get status => data['status']?.toString() ?? 'pending';
  double get total => (data['total'] as num?)?.toDouble() ?? 0;
  int get itemCount => (data['items'] as List?)?.length ?? 0;

  // Parse order date from different possible formats
  DateTime get orderDate {
    final millis = data['orderCreatedAtMillis'];
    if (millis is int) return DateTime.fromMillisecondsSinceEpoch(millis);
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    return DateTime.now();
  }

  // Status color mapping for visual indicators
  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFFF9800);
      case 'preparing': return const Color(0xFF2196F3);
      case 'out_for_delivery': return const Color(0xFF9C27B0);
      case 'delivered': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFF44336);
      default: return Colors.grey;
    }
  }

  // Status icon mapping
  IconData get statusIcon {
    switch (status) {
      case 'pending': return Icons.pending_actions;
      case 'preparing': return Icons.kitchen;
      case 'out_for_delivery': return Icons.delivery_dining;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.shopping_bag;
    }
  }

  // Human-readable status text
  String get statusText {
    switch (status) {
      case 'pending': return 'Pending';
      case 'preparing': return 'Preparing';
      case 'out_for_delivery': return 'On Delivery';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  // Format date for display (Today, Yesterday, X days ago, or formatted date)
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Use passed isDarkMode parameter for consistent theming
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF232323) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4).withOpacity(0.3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Order status icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: statusColor, size: 26),
              ),
              const SizedBox(width: 14),

              // Order details section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Order number and status badge row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            orderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Date and items row
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 12, color: Color(0xFF8B7355)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatDate(orderDate),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8B7355)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.shopping_bag, size: 12, color: Color(0xFF8B7355)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$itemCount items',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8B7355)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Price and address section (right side)
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order total price
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'EGP ${NumberFormat('#,###.##').format(total)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFCB6B2E),
                          ),
                        ),
                      ),
                      // Delivery address (if available)
                      if (data['delivery'] != null && data['delivery']['address'] != null)
                        Text(
                          data['delivery']['address'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B7355),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}