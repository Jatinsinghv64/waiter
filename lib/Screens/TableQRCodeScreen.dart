import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../Firebase/FirestoreService.dart';
import '../Providers/UserProvider.dart';
import '../constants.dart';
import '../utils.dart';

class TableQRCodeScreen extends StatefulWidget {
  final String tableNumber;
  final Map<String, dynamic> tableData;

  const TableQRCodeScreen({
    super.key,
    required this.tableNumber,
    required this.tableData,
  });

  @override
  State<TableQRCodeScreen> createState() => _TableQRCodeScreenState();
}

class _TableQRCodeScreenState extends State<TableQRCodeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _sessionId;
  DateTime? _expiresAt;
  Uri? _orderUri;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final branchId =
          Provider.of<UserProvider>(context, listen: false).currentBranch;
      if (branchId == null) {
        throw InvalidOrderException('Please select a branch first.');
      }

      final session = await FirestoreService.createOrReuseQrSession(
        branchId: branchId,
        tableNumber: widget.tableNumber,
      );

      final sessionId = session['id'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw InvalidOrderException('Unable to create QR session.');
      }

      final expiresAt = session['expiresAt'];
      DateTime? expiresAtDate;
      if (expiresAt is Timestamp) {
        expiresAtDate = expiresAt.toDate();
      } else if (expiresAt is DateTime) {
        expiresAtDate = expiresAt;
      }

      final orderUri = AppConfig.buildCustomerOrderUri(sessionId);

      setState(() {
        _sessionId = sessionId;
        _expiresAt = expiresAtDate;
        _orderUri = orderUri;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = ErrorUtils.getFirebaseErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _copyLink() async {
    if (_orderUri == null) return;
    await Clipboard.setData(ClipboardData(text: _orderUri.toString()));
    if (!mounted) return;
    UIUtils.showSuccessSnackbar(context, 'Link copied to clipboard.');
  }

  String _formatExpiry(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return DateTimeUtils.formatTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final orderUri = _orderUri;
    final isUriValid = orderUri != null && AppConfig.isValidCustomerOrderUri(orderUri);

    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${widget.tableNumber} QR'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSession,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh QR',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildQrContent(isUriValid),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
            SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSession,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent(bool isUriValid) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!isUriValid)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set AppConfig.customerOrderBaseUrl to generate a shareable QR link.',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _orderUri?.toString() ?? '',
                  size: 240,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) {
                    return Text('Unable to generate QR code');
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 24),
          if (_sessionId != null)
            Text(
              'Session: $_sessionId',
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 8),
          Text(
            'Expires at ${_formatExpiry(_expiresAt)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: Icon(Icons.copy),
                  label: Text('Copy Link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
