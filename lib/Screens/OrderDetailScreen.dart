import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Firebase/FirestoreService.dart';
import '../Providers/UserProvider.dart';
import '../constants.dart';

// ==========================================
// HELPER CLASS: RECEIPT GENERATOR
// separates printing logic from UI code
// ==========================================
class ReceiptGenerator {
  static String generateTextReceipt(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln("      ZAYKA RESTAURANT      ");
    buffer.writeln("      Order #${data['dailyOrderNumber']}      ");
    buffer.writeln("----------------------------");
    buffer.writeln("Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}");
    if (data['tableNumber'] != null) buffer.writeln("Table: ${data['tableNumber']}");
    buffer.writeln("----------------------------");

    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    for (var item in items) {
      final name = item['name'];
      final qty = item['quantity'];
      final price = (item['price'] as num).toDouble();
      final total = price * qty;
      buffer.writeln("$qty x $name");
      buffer.writeln("    @ $price          $total");
    }
    buffer.writeln("----------------------------");
    buffer.writeln("TOTAL:        ${data['totalAmount']}");
    buffer.writeln("----------------------------");
    buffer.writeln("      Thank You!      ");
    return buffer.toString();
  }
}

// ==========================================
// WIDGET: ISOLATED TIMER
// Prevents full screen rebuilds every second
// ==========================================
class OrderTimerBadge extends StatefulWidget {
  final Timestamp? timestamp;
  const OrderTimerBadge({Key? key, this.timestamp}) : super(key: key);

  @override
  _OrderTimerBadgeState createState() => _OrderTimerBadgeState();
}

class _OrderTimerBadgeState extends State<OrderTimerBadge> {
  Timer? _timer;
  String _durationString = "--:--";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (widget.timestamp == null) return;
    final duration = DateTime.now().difference(widget.timestamp!.toDate());
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    final newString = hours == "00" ? "$minutes:$seconds" : "$hours:$minutes:$seconds";

    if (newString != _durationString && mounted) {
      setState(() => _durationString = newString);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _durationString,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// MAIN SCREEN
// ==========================================
class OrderDetailScreen extends StatefulWidget {
  final DocumentSnapshot order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final Color primaryColor = const Color(0xFF1976D2);
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Order no longer exists')),
          );
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>;

        // Extract fields with safe defaults
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
        final status = orderData['status']?.toString() ?? 'unknown';
        final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';
        final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
        final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '#';
        final tableNumber = orderData['tableNumber']?.toString();
        final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final timestamp = orderData['timestamp'] as Timestamp?;
        final placedBy = orderData['placedByUserId']?.toString();
        final carPlateNumber = orderData['carPlateNumber']?.toString();
        final specialInstructions = orderData['specialInstructions']?.toString();
        final cancellationReason = orderData['cancellationReason']?.toString();
        final returnReason = orderData['returnReason']?.toString();

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #$dailyOrderNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : 'Just now',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // PERFORMANCE FIX: Isolated timer widget
                if (status != 'paid' && status != 'cancelled')
                  OrderTimerBadge(timestamp: timestamp),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'return') _handleReturnAction(snapshot.data!.id);
                  if (value == 'print') _handlePrint(orderData);
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(children: [Icon(Icons.print, color: Colors.grey), SizedBox(width: 8), Text('Print Ticket')]),
                    ),
                    if (['served', 'paid', 'prepared'].contains(status))
                      const PopupMenuItem(
                        value: 'return',
                        child: Row(children: [Icon(Icons.assignment_return, color: Colors.orange), SizedBox(width: 8), Text('Return / Issue')]),
                      ),
                  ];
                },
              ),
            ],
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildOrderTimeline(status, paymentStatus),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status == 'cancelled')
                        _buildAlertBanner("ORDER CANCELLED", Colors.red, cancellationReason),
                      if (status == 'returned')
                        _buildAlertBanner("ORDER RETURNED", Colors.orange, cancellationReason),
                      if (returnReason != null && status == 'preparing')
                        _buildAlertBanner("SENT BACK TO KITCHEN", Colors.blue, "Reason: $returnReason"),

                      _buildLocationCard(orderType, tableNumber, carPlateNumber, specialInstructions),
                      const SizedBox(height: 16),
                      _buildItemsList(items),
                      const SizedBox(height: 16),
                      _buildFinancials(totalAmount, paymentStatus),
                      const SizedBox(height: 24),
                      if (placedBy != null)
                        Text('Order placed by: $placedBy', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ),
              _buildBottomActionPanel(context, snapshot.data!.id, status, paymentStatus, orderType),
            ],
          ),
        );
      },
    );
  }

  // ... [Keep existing UI helper methods: _buildAlertBanner, _buildOrderTimeline, _buildTimelineStep, _buildTimelineLine, _buildLocationCard, _buildItemsList, _buildFinancials] ...

  // Reuse your existing UI Widget methods here.
  // For brevity, I am pasting the AlertBanner as it's new, ensure you keep the others from previous code.
  Widget _buildAlertBanner(String title, Color color, String? subtitle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          if (subtitle != null) Text(subtitle, style: TextStyle(color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline(String status, String paymentStatus) {
    // Same as previous version
    final steps = ['pending', 'preparing', 'prepared', 'served', 'paid'];
    int currentStep = steps.indexOf(status);
    if (status == 'served' && paymentStatus == 'paid') currentStep = 4;
    if (status == 'paid') currentStep = 4;

    if (status == 'cancelled' || status == 'returned') return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimelineStep(Icons.assignment, "New", currentStep >= 0, true),
          _buildTimelineLine(currentStep >= 1),
          _buildTimelineStep(Icons.soup_kitchen, "Kitchen", currentStep >= 1, currentStep == 1),
          _buildTimelineLine(currentStep >= 2),
          _buildTimelineStep(Icons.room_service, "Ready", currentStep >= 2, currentStep == 2),
          _buildTimelineLine(currentStep >= 3),
          _buildTimelineStep(Icons.dining, "Served", currentStep >= 3, currentStep == 3),
          _buildTimelineLine(currentStep >= 4),
          _buildTimelineStep(Icons.check_circle, "Paid", currentStep >= 4, currentStep == 4),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(IconData icon, String label, bool isActive, bool isCurrent) {
    final color = isActive ? primaryColor : Colors.grey[300];
    return Column(
      children: [
        CircleAvatar(radius: 14, backgroundColor: color, child: Icon(icon, size: 14, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black87 : Colors.grey)),
      ],
    );
  }

  Widget _buildTimelineLine(bool isActive) {
    return Expanded(child: Container(height: 2, color: isActive ? primaryColor : Colors.grey[300]));
  }

  Widget _buildLocationCard(String type, String? table, String? carPlate, String? instructions) {
    final isTakeaway = type == 'takeaway';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isTakeaway ? Colors.orange[50] : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Icon(isTakeaway ? Icons.shopping_bag : Icons.table_restaurant, color: isTakeaway ? Colors.orange : Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isTakeaway ? "Takeaway Order" : "Table $table", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (isTakeaway && carPlate != null) Text("Car: $carPlate", style: TextStyle(color: Colors.grey[600])),
                if (instructions != null && instructions.isNotEmpty) Text("Note: $instructions", style: TextStyle(color: Colors.red[400], fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (c, i) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final hasNote = item['specialInstructions'] != null && item['specialInstructions'].toString().isNotEmpty;
          final variant = item['variantName'] ?? item['selectedVariant'];
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
              child: Text("${quantity}x", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
            ),
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (variant != null) Text("Variant: $variant", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (hasNote) Text("Note: ${item['specialInstructions']}", style: const TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ),
            trailing: Text(AppConfig.formatCurrency((price * quantity)), style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  Widget _buildFinancials(double total, String paymentStatus) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL AMOUNT", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(AppConfig.formatCurrency(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: paymentStatus == 'paid' ? Colors.green[100] : Colors.red[100], borderRadius: BorderRadius.circular(20)),
            child: Text(paymentStatus == 'paid' ? "PAID" : "UNPAID", style: TextStyle(color: paymentStatus == 'paid' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomActionPanel(BuildContext context, String orderId, String status, String paymentStatus, String orderType) {
    // Hidden for terminal states to clean up UI
    if (status == 'cancelled' || status == 'returned') return const SizedBox.shrink();
    if (status == 'served' && paymentStatus == 'paid') return const SizedBox.shrink();

    final String? undoStatus = _getUndoStatus(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (undoStatus != null) ...[
              SizedBox(
                width: 50,
                child: IconButton(
                  onPressed: _isUpdating ? null : () => _handleUndo(orderId, undoStatus, orderType),
                  icon: const Icon(Icons.undo),
                  color: Colors.orange,
                  tooltip: 'Undo Status',
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (status != 'paid')
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => _handleCancel(orderId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : () => _handleMainAction(context, orderId, status, paymentStatus, orderType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_getMainActionText(status, paymentStatus), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================

  void _handlePrint(Map<String, dynamic> data) {
    // Uses the isolated Helper Class
    final receiptText = ReceiptGenerator.generateTextReceipt(data);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.print), SizedBox(width: 8), Text("Printing Ticket...")]),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            child: Text(receiptText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent to Printer (Simulation)")));
              },
              child: const Text("Print")
          ),
        ],
      ),
    );
  }

  Future<void> _handleReturnAction(String orderId) async {
    // Robust dialog usage
    final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Row(
              children: const [Icon(Icons.assignment_return, color: Colors.orange), SizedBox(width: 10), Text("Handle Return")],
            ),
            content: const Text("How do you want to resolve this return?"),
            actions: [
              TextButton(
                child: const Text("Cancel Order", style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.pop(ctx, 'cancel'),
              ),
              ElevatedButton(
                child: const Text("Send to Kitchen"),
                onPressed: () => Navigator.pop(ctx, 'kitchen'),
              )
            ]
        )
    );

    if (!mounted || result == null) return;

    if (result == 'cancel') {
      _handleCancel(orderId);
    } else if (result == 'kitchen') {
      _showSendToKitchenDialog(orderId);
    }
  }

  void _showSendToKitchenDialog(String orderId) {
    final noteController = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Send back to Kitchen"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please specify the reason for the kitchen staff:"),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: "Reason / Feedback", hintText: "e.g. Too salty, Cold food", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
              ElevatedButton(
                  child: const Text("Send"),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _sendOrderToKitchen(orderId, noteController.text);
                  }
              )
            ]
        )
    );
  }

  Future<void> _sendOrderToKitchen(String orderId, String reason) async {
    setState(() => _isUpdating = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch!;

    try {
      await FirestoreService.updateOrderStatusWithTable(branchId, orderId, 'preparing', validateTransition: false);

      await FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
        'returnReason': reason.isEmpty ? 'Sent back to kitchen' : reason,
        'lastReturnedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order sent back to Kitchen')));
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ... [Keep existing helper methods: _getUndoStatus, _getMainActionText, _handleUndo, _handleMainAction, _handleCancel, _showPaymentModal, _paymentOption, _submitPayment] ...

  // Re-paste logic helpers for completeness if overwriting file
  String? _getUndoStatus(String currentStatus) {
    if (currentStatus == 'preparing') return 'pending';
    if (currentStatus == 'prepared') return 'preparing';
    if (currentStatus == 'served') return 'prepared';
    return null;
  }

  String _getMainActionText(String status, String paymentStatus) {
    if (status == 'pending') return 'Mark Preparing';
    if (status == 'preparing') return 'Mark Ready';
    if (status == 'prepared') return 'Mark Served';
    if (status == 'served' && paymentStatus != 'paid') return 'Collect Payment';
    return 'Close';
  }

  Future<void> _handleUndo(String orderId, String targetStatus, String orderType) async {
    setState(() => _isUpdating = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null) {
      setState(() => _isUpdating = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('Orders').doc(orderId).get();
      final data = doc.data() as Map<String, dynamic>;
      final tableNumber = data['tableNumber']?.toString();

      await FirestoreService.updateOrderStatusWithTable(
        branchId,
        orderId,
        targetStatus,
        tableNumber: orderType == 'dine_in' ? tableNumber : null,
        validateTransition: false,
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Undone: Order is now $targetStatus")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Undo Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleMainAction(BuildContext context, String orderId, String status, String paymentStatus, String orderType) async {
    setState(() => _isUpdating = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branch not found"), backgroundColor: Colors.red));
        setState(() => _isUpdating = false);
      }
      return;
    }

    try {
      if (status == 'pending') {
        await FirestoreService.updateOrderStatusWithTable(branchId, orderId, 'preparing', validateTransition: false);
      } else if (status == 'preparing') {
        await FirestoreService.updateOrderStatusWithTable(branchId, orderId, 'prepared', validateTransition: false);
      } else if (status == 'prepared') {
        final email = userProvider.userEmail ?? 'unknown';
        await FirestoreService.claimAndServeOrder(branchId: branchId, orderId: orderId, waiterEmail: email, orderType: orderType);
      } else if (status == 'served' && paymentStatus != 'paid') {
        _showPaymentModal(context, orderId, branchId, orderType);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleCancel(String orderId) async {
    final TextEditingController reasonController = TextEditingController();
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(children: const [Icon(Icons.cancel_outlined, color: Colors.red), SizedBox(width: 8), Text('Cancel Order')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this order?', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(labelText: 'Reason (Optional)', hintText: 'e.g. Out of stock', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep Order')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Cancel Order')),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null) {
      if (mounted) setState(() => _isUpdating = false);
      return;
    }

    try {
      final orderSnap = await FirebaseFirestore.instance.collection('Orders').doc(orderId).get();
      final orderData = orderSnap.data() as Map<String, dynamic>;
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
      final tableNumber = orderData['tableNumber']?.toString();

      await FirestoreService.updateOrderStatusWithTable(
        branchId,
        orderId,
        'cancelled',
        tableNumber: orderType == 'dine_in' ? tableNumber : null,
        validateTransition: false,
      );

      if (reasonController.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('Orders').doc(orderId).update({'cancellationReason': reasonController.text.trim()});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled'), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showPaymentModal(BuildContext context, String orderId, String branchId, String orderType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _paymentOption(Icons.money, "Cash", Colors.green, () => _submitPayment(orderId, branchId, 'cash', orderType))),
                const SizedBox(width: 16),
                Expanded(child: _paymentOption(Icons.credit_card, "Card", Colors.blue, () => _submitPayment(orderId, branchId, 'card', orderType))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayment(String orderId, String branchId, String method, String orderType) async {
    Navigator.pop(context); // close modal
    setState(() => _isUpdating = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('Orders').doc(orderId).get();
      if (!doc.exists || doc.data() == null) throw Exception("Order data not found");

      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['totalAmount'] as num).toDouble();
      final email = Provider.of<UserProvider>(context, listen: false).userEmail ?? 'staff';

      await FirestoreService.claimAndPayOrder(
        branchId: branchId,
        orderId: orderId,
        waiterEmail: email,
        paymentMethod: method,
        amount: amount,
        orderType: orderType,
        tableNumber: orderType == 'dine_in' ? data['tableNumber']?.toString() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}