import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Widgets/OrderService.dart';
import '../Widgets/BranchFilterService.dart';
import 'package:intl/intl.dart';
import '../Widgets/OrderUIComponents.dart';
import '../main.dart';
import '../constants.dart';
import '../Widgets/PrintingService.dart';

class OrdersScreenLarge extends StatefulWidget {
  final String? initialOrderType;
  final String? initialOrderId;

  const OrdersScreenLarge({
    super.key,
    this.initialOrderType,
    this.initialOrderId,
  });

  @override
  State<OrdersScreenLarge> createState() => _OrdersScreenLargeState();
}

class _OrdersScreenLargeState extends State<OrdersScreenLarge>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _orderTypeMap = {
    'Delivery': 'delivery',
    'Takeaway': 'takeaway',
    'Pickup': 'pickup',
    'Dine-in': 'dine_in',
  };

  String? _selectedOrderId;
  DocumentSnapshot? _selectedOrderDoc;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _orderTypeMap.length, vsync: this);

    // Set initial selection if provided
    if (widget.initialOrderId != null) {
      _selectedOrderId = widget.initialOrderId;
    }

    // Set initial tab if provided
    if (widget.initialOrderType != null) {
      final index =
          _orderTypeMap.values.toList().indexOf(widget.initialOrderType!);
      if (index != -1) {
        _tabController.animateTo(index);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reusing the same providers
    final userScope = context.watch<UserScopeService>();
    final branchFilter = context.watch<BranchFilterService>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // LEFT PANE: Order List (35%)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  _buildHeaderAndTabs(context, userScope, branchFilter),
                  _buildStatusFilterBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _orderTypeMap.values.map((type) {
                        return _buildOrderList(type, userScope, branchFilter);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // RIGHT PANE: Order Details (65%)
          Expanded(
            flex: 6,
            child: _selectedOrderDoc != null
                ? _buildOrderDetailPane(context, userScope)
                : _buildEmptyDetailState(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndTabs(BuildContext context, UserScopeService userScope,
      BranchFilterService branchFilter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple),
              ),
              if (userScope.branchIds.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: branchFilter.selectedBranchId ??
                        BranchFilterService.allBranchesValue,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.deepPurple),
                    style: const TextStyle(
                        color: Colors.deepPurple, fontWeight: FontWeight.w600),
                    onChanged: (val) => branchFilter.selectBranch(
                        val == BranchFilterService.allBranchesValue
                            ? null
                            : val),
                    items: [
                      DropdownMenuItem(
                          value: BranchFilterService.allBranchesValue,
                          child: const Text('All Branches')),
                      ...userScope.branchIds.map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(branchFilter.getBranchName(id))))
                    ],
                  ),
                ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: _orderTypeMap.keys.map((t) => Tab(text: t)).toList(),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildStatusFilterBar() {
    // Simplified horizontal scrollable chips
    final statuses = [
      'all',
      AppConstants.statusPending,
      AppConstants.statusPreparing,
      AppConstants.statusPrepared,
      AppConstants.statusRiderAssigned,
      AppConstants.statusDelivered,
      AppConstants.statusCancelled
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final isSelected = _selectedStatusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                  status == 'all' ? 'All' : StatusUtils.getDisplayText(status)),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedStatusFilter = val ? status : 'all');
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.deepPurple.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList(String orderType, UserScopeService userScope,
      BranchFilterService branchFilter) {
    final filterBranchIds =
        branchFilter.getFilterBranchIds(userScope.branchIds);

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: OrderService().getOrdersStreamMerged(
          orderType: orderType,
          status: _selectedStatusFilter,
          userScope: userScope,
          filterBranchIds: filterBranchIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No orders found."));
        }

        final orders = snapshot.data!;

        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data();
            final isSelected = _selectedOrderId == order.id;

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              selected: isSelected,
              selectedTileColor: Colors.deepPurple.withOpacity(0.05),
              onTap: () {
                setState(() {
                  _selectedOrderId = order.id;
                  _selectedOrderDoc = order;
                });
              },
              leading: CircleAvatar(
                backgroundColor:
                    isSelected ? Colors.deepPurple : Colors.grey[200],
                child: Icon(Icons.receipt,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: 20),
              ),
              title: Text(
                'Order #${data['dailyOrderNumber'] ?? order.id.substring(order.id.length > 5 ? order.id.length - 5 : 0).toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.deepPurple : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(data['customerName'] ?? 'Guest'),
                  const SizedBox(height: 4),
                  _buildSmallStatusBadge(data['status'] ?? 'pending'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'QAR ${(data['totalAmount'] ?? 0).toString()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data['timestamp'] != null
                        ? DateFormat('MMM d, hh:mm a')
                            .format((data['timestamp'] as Timestamp).toDate())
                        : 'N/A',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSmallStatusBadge(String status) {
    Color color = StatusUtils.getColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // --- Right Pane: Details ---

  Widget _buildEmptyDetailState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Select an order to view details",
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailPane(
      BuildContext context, UserScopeService userScope) {
    if (_selectedOrderDoc == null) return const SizedBox.shrink();

    // Using a ValueKey ensures the widget rebuilds/resets when selection changes
    return Container(
      key: ValueKey(_selectedOrderId),
      padding: const EdgeInsets.all(32),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _OrderDetailsContent(
            order: _selectedOrderDoc!, userScope: userScope),
      ),
    );
  }
}

// Separate widget for details to keep code clean
class _OrderDetailsContent extends StatelessWidget {
  final DocumentSnapshot order;
  final UserScopeService userScope;

  const _OrderDetailsContent({required this.order, required this.userScope});

  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    // Reuse OrderUIComponents for consistency, but laid out nicely

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${data['dailyOrderNumber']?.toString() ?? order.id.substring(order.id.length > 5 ? order.id.length - 5 : 0).toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        data['timestamp'] != null
                            ? DateFormat('MMM d, hh:mm a').format(
                                (data['timestamp'] as Timestamp).toDate())
                            : 'N/A',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              _buildBigStatusBadge(data['status'] ?? 'pending'),
            ],
          ),
        ),

        // Body (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info Section
                _buildSectionTitle('Customer Details'),
                const SizedBox(height: 16),
                _buildCustomerInfo(data),
                const SizedBox(height: 32),

                // Items Section
                _buildSectionTitle('Order Items'),
                const SizedBox(height: 16),
                _buildItemsList(data['items'] ?? []),
                const SizedBox(height: 32),

                // Payment Section
                _buildSectionTitle('Payment Summary'),
                const SizedBox(height: 16),
                _buildPaymentSummary(data),
              ],
            ),
          ),
        ),

        // Action Bar (Bottom)
        _buildActionBar(context, data),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildCustomerInfo(Map<String, dynamic> data) {
    String addressText = 'N/A';
    final rawAddress = data['deliveryAddress'];
    if (rawAddress is Map) {
      addressText =
          '${rawAddress['street'] ?? ''}, ${rawAddress['city'] ?? ''}';
    } else if (rawAddress is String) {
      addressText = rawAddress;
    }

    return Row(
      children: [
        const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 16),
        // Wrapped in Expanded to prevent overflow
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['customerName']?.toString() ?? 'Guest',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(data['customerPhone']?.toString() ?? 'No Phone',
                  style: TextStyle(color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 16), // Gap instead of Spacer for better control
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.red),
                  SizedBox(width: 4),
                  Text('Delivery Address',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                addressText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(List items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              color: Colors.grey[200],
              child: item['imageUrl'] != null
                  ? Image.network(
                      item['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.fastfood, color: Colors.grey),
                    )
                  : const Icon(Icons.fastfood, color: Colors.grey),
            ),
          ),
          title: Row(
            children: [
              Text(item['name'] ?? 'Item'),
              const SizedBox(width: 8),
              if (item['tags'] is Map)
                ...(item['tags'] as Map)
                    .entries
                    .where((e) => e.value == true)
                    .map((e) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTagColor(e.key).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: _getTagColor(e.key).withOpacity(0.3)),
                          ),
                          child: Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTagColor(e.key),
                            ),
                          ),
                        ))
                    .toList(),
            ],
          ),
          subtitle: Text('Qty: ${item['quantity']}'),
          trailing: Text('QAR ${item['price']}'),
        );
      },
    );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'Healthy':
        return Colors.green;
      case 'Vegetarian':
        return Colors.teal;
      case 'Vegan':
        return Colors.green.shade700;
      case 'Spicy':
        return Colors.red;
      case 'Popular':
        return Colors.amber;
      default:
        return Colors.deepPurple;
    }
  }

  Widget _buildPaymentSummary(Map<String, dynamic> data) {
    return Column(
      children: [
        _buildSummaryRow('Subtotal', data['subtotal'] ?? 0),
        _buildSummaryRow('Delivery Fee', data['deliveryFee'] ?? 0),
        const Divider(height: 24),
        _buildSummaryRow('Total', data['totalAmount'] ?? 0, isTotal: true),
      ],
    );
  }

  Widget _buildSummaryRow(String label, dynamic amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 18 : 14)),
          Text('QAR $amount',
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 18 : 14,
                  color: isTotal ? Colors.deepPurple : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildBigStatusBadge(String status) {
    Color color = StatusUtils.getColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, Map<String, dynamic> data) {
    // Actions based on status
    final status = data['status'] ?? 'pending';
    final isPending = status == 'pending';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => PrintingService.printReceipt(context, order),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Receipt'),
          ),
          const SizedBox(width: 16),
          if (isPending) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                OrderService().updateOrderStatus(context, order.id, 'preparing',
                    currentUserEmail: userScope.userIdentifier);
              },
              child: const Text('Accept Order'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _OrderStatusDialog(
                    order: order,
                    userScope: userScope,
                  ),
                );
              },
              child: const Text('Manage Order'),
            ),
          ]
        ],
      ),
    );
  }
}

class _OrderStatusDialog extends StatelessWidget {
  final DocumentSnapshot order;
  final UserScopeService userScope;

  const _OrderStatusDialog({required this.order, required this.userScope});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.deepPurple),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Update Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAction(
              context,
              'Mark as Preparing',
              Icons.soup_kitchen,
              Colors.orange,
              'preparing',
            ),
            _buildAction(
              context,
              'Mark as Ready',
              Icons.check_circle_outline,
              Colors.blue,
              'prepared',
            ),
            _buildAction(
              context,
              'Out for Delivery',
              Icons.delivery_dining,
              Colors.purple,
              'out_for_delivery',
            ),
            _buildAction(
              context,
              'Mark as Delivered',
              Icons.done_all,
              Colors.green,
              'delivered',
            ),
            const Divider(height: 32),
            _buildAction(
              context,
              'Cancel Order',
              Icons.cancel_outlined,
              Colors.red,
              'cancelled',
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, String label, IconData icon,
      Color color, String status,
      {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          OrderService().updateOrderStatus(
            context,
            order.id,
            status,
            currentUserEmail: userScope.userIdentifier,
            reason: isDestructive ? 'Cancelled by Admin manually' : null,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red[700] : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
