// Admin Order Driver Management Screen - Allows admins to assign and manage drivers for customer orders
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrdersDriversScreen extends StatefulWidget {
  const AdminOrdersDriversScreen({super.key});

  @override
  State<AdminOrdersDriversScreen> createState() => _AdminOrdersDriversScreenState();
}

class _AdminOrdersDriversScreenState extends State<AdminOrdersDriversScreen> {
  // Search functionality controllers and state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Driver selection for edit functionality
  String? _selectedDriverName;      // Currently selected driver from dropdown
  String? _editingOrderId;          // ID of order being edited
  Map<String, dynamic>? _editingOrderData;  // Full order data for editing

  // Predefined list of available drivers for assignment
  static const List<String> _driverNames = [
    'Michael Johnson',
    'Omar Hassan',
    'Ahmed Samir',
    'Youssef Ali',
    'Karim Mostafa',
    'Hassan Adel',
    'Mina Nabil',
    'Ibrahim Tarek',
  ];

  @override
  void initState() {
    super.initState();
    _checkOrdersCollection(); // Verify orders exist when screen loads
  }

  @override
  void dispose() {
    _searchController.dispose(); // Clean up search controller
    super.dispose();
  }

  // Check if orders collection has any data, show error if empty
  Future<void> _checkOrdersCollection() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shop_orders')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _errorMessage = 'No orders found.');
      } else {
        setState(() => _errorMessage = null);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error connecting to Firestore: $e');
    }
  }

  // Update driver assignment for a specific order in Firestore
  Future<void> _updateOrderDriver(String orderId, String driverName) async {
    setState(() => _isLoading = true);

    try {
      // Fetch current order data to preserve existing fields
      final orderDoc = await FirebaseFirestore.instance
          .collection('shop_orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        _showSnackBar('Order not found', isError: true);
        return;
      }

      final currentData = orderDoc.data() as Map<String, dynamic>;

      // Create updated driver map preserving existing rating if available
      final updatedDriver = {
        'name': driverName,
        'rating': currentData['driver']?['rating'] ?? 0.0,
      };

      // Update Firestore document with new driver assignment
      await FirebaseFirestore.instance
          .collection('shop_orders')
          .doc(orderId)
          .update({
        'driver': updatedDriver,
        'updatedAt': FieldValue.serverTimestamp(), // Track when assignment changed
      });

      _showSnackBar('Driver assigned successfully to $driverName');
      if (mounted) Navigator.pop(context); // Close modal after success
    } catch (e) {
      _showSnackBar('Error updating driver: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Display modal bottom sheet for driver selection and assignment
  void _showDriverEditForm(Map<String, dynamic> orderData, String orderId) {
    _editingOrderId = orderId;
    _editingOrderData = orderData;

    // Get current driver name if already assigned
    final currentDriver = orderData['driver']?['name']?.toString();
    _selectedDriverName = currentDriver;

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
                  // Modal title
                  Text(
                    'Assign Driver',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Display order identifier
                  Text(
                    'Order: ${orderData['orderId'] ?? orderId.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFFCB6B2E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Driver selection dropdown
                  _buildDriverDropdown(isDarkMode),
                  const SizedBox(height: 24),
                  // Action buttons (Cancel & Assign)
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
                          onPressed: _isLoading || _selectedDriverName == null
                              ? null
                              : () async {
                            await _updateOrderDriver(orderId, _selectedDriverName!);
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
                              : const Text(
                            'Assign Driver',
                            style: TextStyle(
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

  // Build driver selection dropdown widget with custom styling
  Widget _buildDriverDropdown(bool isDarkMode) {
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
          value: _selectedDriverName,
          isExpanded: true,
          hint: Text(
            'Select a driver',
            style: TextStyle(
              color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
            ),
          ),
          dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFCB6B2E)),
          style: TextStyle(
            color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
            fontSize: 16,
          ),
          items: _driverNames.map((String driverName) {
            return DropdownMenuItem<String>(
              value: driverName,
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, size: 18, color: Color(0xFFCB6B2E)),
                  const SizedBox(width: 8),
                  Text(driverName),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedDriverName = value);
            }
          },
        ),
      ),
    );
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

  // Format timestamp/date for display in human-readable format
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

    // Return appropriate format based on age of order
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

  // Format price with EGP currency symbol and proper number formatting
  String _formatPrice(double price) {
    return 'EGP ${NumberFormat('#,###.##').format(price)}';
  }

  // Convert order status code to human-readable text
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'preparing': return 'Preparing';
      case 'out_for_delivery': return 'On Delivery';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  // Get color code for order status badge
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFFF9800);      // Orange for pending
      case 'preparing': return const Color(0xFF2196F3);    // Blue for preparing
      case 'out_for_delivery': return const Color(0xFF9C27B0); // Purple for delivery
      case 'delivered': return const Color(0xFF4CAF50);    // Green for delivered
      case 'cancelled': return const Color(0xFFF44336);    // Red for cancelled
      default: return Colors.grey;
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
          'Order Driver Management',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar for filtering orders by ID or driver name
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
                        hintText: 'Search by order ID or driver name...',
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
          // Orders List - Real-time stream from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shop_orders')
                  .orderBy('orderCreatedAtMillis', descending: true) // Newest first
                  .snapshots(),
              builder: (context, snapshot) {
                // Loading state while fetching data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFCB6B2E)),
                        SizedBox(height: 16),
                        Text('Loading orders...'),
                      ],
                    ),
                  );
                }

                // Error state display
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading orders: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFF8B7355)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkOrdersCollection,
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

                final orders = snapshot.data!.docs;

                // Empty state - no orders exist
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: const Color(0xFFCB6B2E).withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Orders will appear here once customers place them',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Apply search filter by order ID or driver name
                final filteredOrders = _searchQuery.isEmpty
                    ? orders
                    : orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = data['orderId']?.toString().toLowerCase() ?? '';
                  final driverName = data['driver']?['name']?.toString().toLowerCase() ?? '';
                  return orderId.contains(_searchQuery) ||
                      driverName.contains(_searchQuery);
                }).toList();

                // No search results found
                if (filteredOrders.isEmpty) {
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
                          'No orders found',
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

                // Render filtered order list
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final doc = filteredOrders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;

                    // Extract order data with fallback values
                    final orderNumber = data['orderId']?.toString() ?? orderId.substring(0, 8);
                    final status = data['status']?.toString() ?? 'pending';
                    final total = (data['total'] as num?)?.toDouble() ?? 0;
                    final itemCount = (data['items'] as List?)?.length ?? 0;
                    final driver = data['driver'] as Map<String, dynamic>?;
                    final driverName = driver?['name']?.toString() ?? 'Unassigned';
                    final driverRating = driver?['rating'] as double? ?? 0.0;

                    // Parse order date from different possible formats
                    DateTime orderDate;
                    final millis = data['orderCreatedAtMillis'];
                    if (millis is int) {
                      orderDate = DateTime.fromMillisecondsSinceEpoch(millis);
                    } else {
                      final createdAt = data['createdAt'];
                      if (createdAt is Timestamp) {
                        orderDate = createdAt.toDate();
                      } else {
                        orderDate = DateTime.now();
                      }
                    }

                    // Individual order card widget
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
                          onTap: () => _showDriverEditForm(data, orderId), // Open edit modal on tap
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Order Icon Container (gradient background)
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
                                    child: Icon(
                                      Icons.shopping_bag,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Order Information Section
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Order number and status badge row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              orderNumber,
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
                                              color: _getStatusColor(status).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(status).toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _getStatusColor(status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Date and items count row
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 12, color: Color(0xFFCB6B2E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(orderDate),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.shopping_bag, size: 12, color: Color(0xFFCB6B2E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$itemCount items',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Driver information row with rating
                                      Row(
                                        children: [
                                          const Icon(Icons.delivery_dining, size: 12, color: Color(0xFFCB6B2E)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Driver: $driverName',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: driverName != 'Unassigned'
                                                    ? const Color(0xFF4CAF50)  // Green for assigned
                                                    : Colors.orange,          // Orange for unassigned
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Display rating star if driver has rating
                                          if (driverRating > 0) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.star, size: 10, color: const Color(0xFFFFB800)),
                                            const SizedBox(width: 2),
                                            Text(
                                              driverRating.toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFFFB800),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Price and Edit Button Section (Right side)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Order total price
                                    Text(
                                      _formatPrice(total),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCB6B2E),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Edit button to change driver assignment
                                    IconButton(
                                      onPressed: () => _showDriverEditForm(data, orderId),
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFCB6B2E), size: 20),
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