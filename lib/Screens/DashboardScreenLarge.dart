import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Widgets/OrderService.dart';
import '../Widgets/BranchFilterService.dart';
import '../main.dart';

class DashboardScreenLarge extends StatelessWidget {
  final Function(int) onTabChange;

  const DashboardScreenLarge({super.key, required this.onTabChange});

  // --- Helper Methods using OrderService (Duplicated for independence) ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getTodayOrdersStream(
      BuildContext context) {
    final userScope = Provider.of<UserScopeService>(context, listen: true);
    final branchFilter =
        Provider.of<BranchFilterService>(context, listen: true);
    final filterBranchIds =
        branchFilter.getFilterBranchIds(userScope.branchIds);
    return OrderService().getTodayOrdersStream(
        userScope: userScope, filterBranchIds: filterBranchIds);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getActiveDriversStream(
      BuildContext context) {
    final userScope = Provider.of<UserScopeService>(context, listen: true);
    final branchFilter =
        Provider.of<BranchFilterService>(context, listen: true);
    final filterBranchIds =
        branchFilter.getFilterBranchIds(userScope.branchIds);
    return OrderService().getActiveDriversStream(
        userScope: userScope, filterBranchIds: filterBranchIds);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getAvailableMenuItemsStream(
      BuildContext context) {
    final userScope = Provider.of<UserScopeService>(context, listen: true);
    final branchFilter =
        Provider.of<BranchFilterService>(context, listen: true);
    final filterBranchIds =
        branchFilter.getFilterBranchIds(userScope.branchIds);
    return OrderService().getAvailableMenuItemsStream(
        userScope: userScope, filterBranchIds: filterBranchIds);
  }

  @override
  Widget build(BuildContext context) {
    final userScope = context.watch<UserScopeService>();
    final branchFilter = context.watch<BranchFilterService>();

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, userScope, branchFilter),
            const SizedBox(height: 32),
            _buildStatCardsRow(context),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Orders - taking full width if no chart yet, or split if chart added
                Expanded(
                  child: _buildRecentOrdersSection(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserScopeService userScope,
      BranchFilterService branchFilter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back! Here is what\'s happening today.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        if (userScope.branchIds.length > 1)
          _buildLargeBranchSelector(context, branchFilter, userScope),
      ],
    );
  }

  Widget _buildLargeBranchSelector(BuildContext context,
      BranchFilterService branchFilter, UserScopeService userScope) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: branchFilter.selectedBranchId ??
              BranchFilterService.allBranchesValue,
          icon: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.deepPurple),
          ),
          style: const TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              branchFilter.selectBranch(
                  newValue == BranchFilterService.allBranchesValue
                      ? null
                      : newValue);
            }
          },
          items: [
            DropdownMenuItem<String>(
              value: BranchFilterService.allBranchesValue,
              child: const Text('All Branches'),
            ),
            ...userScope.branchIds.map((id) {
              return DropdownMenuItem<String>(
                value: id,
                child: Text(branchFilter.getBranchName(id)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatWrapper(
            stream: _getTodayOrdersStream(context),
            title: "Today's Orders",
            icon: Icons.shopping_bag_outlined,
            color: Colors.blueAccent,
            onTap: () => onTabChange(2),
            formatter: (docs) => docs.length.toString(),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatWrapper(
            stream: _getActiveDriversStream(context),
            title: "Active Riders",
            icon: Icons.delivery_dining_outlined,
            color: Colors.green,
            onTap: () => onTabChange(4),
            formatter: (docs) => docs.length.toString(),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatWrapper(
            stream: _getTodayOrdersStream(context),
            title: "Total Revenue",
            icon: Icons.attach_money_outlined,
            color: Colors.orangeAccent,
            onTap: () => onTabChange(2),
            formatter: (docs) =>
                'QAR ${OrderService.calculateRevenue(docs).toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatWrapper(
            stream: _getAvailableMenuItemsStream(context),
            title: "Menu Items",
            icon: Icons.restaurant_menu,
            color: Colors.purpleAccent,
            onTap: () => onTabChange(1),
            formatter: (docs) => docs.length.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatWrapper({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
        formatter,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "...";
        if (snapshot.hasData) {
          value = formatter(snapshot.data!.docs);
        }
        return _buildLargeStatCard(title, value, icon, color, onTap);
      },
    );
  }

  Widget _buildLargeStatCard(String title, String value, IconData icon,
      Color color, VoidCallback onTap) {
    return Container(
      height: 175,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.grey[300], size: 20),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Orders",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => onTabChange(2), // Go to Orders tab
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _getTodayOrdersStream(context),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final orders = snapshot.data!.docs
                  .take(8)
                  .toList(); // Show more orders on large screen
              if (orders.isEmpty) return const Text("No orders yet today.");

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey[100], height: 32),
                itemBuilder: (context, index) {
                  final data = orders[index].data();
                  final id = orders[index].id;
                  // Simple list item for dashboard, detailed view is in Orders tab
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: Colors.deepPurple, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order #${data['dailyOrderNumber']?.toString() ?? id.substring(id.length - 5).toUpperCase()}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              data['customerName'] ?? 'Guest',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(data['status'] ?? 'pending'),
                      const SizedBox(width: 32),
                      Text(
                        'QAR ${(data['totalAmount'] ?? 0).toString()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'delivered') color = Colors.green;
    if (status == 'pending') color = Colors.orange;
    if (status == 'preparing') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
