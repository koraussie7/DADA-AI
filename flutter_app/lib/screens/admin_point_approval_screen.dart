import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminPointApprovalScreen extends StatefulWidget {
  const AdminPointApprovalScreen({super.key});

  @override
  State<AdminPointApprovalScreen> createState() =>
      _AdminPointApprovalScreenState();
}

class _AdminPointApprovalScreenState extends State<AdminPointApprovalScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _pendingCharges = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _adminId;
  int _selectedTab = 0; // 0 = pending, 1 = history

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final charges = await _adminService.getPendingPointCharges();
    final history = await _adminService.getChargeHistory(limit: 100);
    if (mounted) {
      setState(() {
        _pendingCharges = charges;
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveCharge(String chargeId, bool isApprove) async {
    final result = await _adminService.approvePointCharge(
      chargeId: chargeId,
      action: isApprove ? "approve" : "reject",
      adminId: _adminId,
    );

    if (!mounted) return;

    if (result['status'] == 'approved' || result['status'] == 'rejected') {
      setState(() {
        _pendingCharges.removeWhere((c) => c['id'] == chargeId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApprove ? "✅ 승인 완료" : "❌ 거부 완료"),
          backgroundColor:
              isApprove ? Colors.green : Colors.red,
        ),
      );
      _loadData(); // Refresh history too
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("오류: ${result['message'] ?? '알 수 없는 오류'}"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("DADA Point 충전 관리"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? const Color(0xFF6B46C1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "승인 대기",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_pendingCharges.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${_pendingCharges.length}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? const Color(0xFF6B46C1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "전체 내역",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildPendingList()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingCharges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              "모든 충전 요청이 처리되었습니다",
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _pendingCharges.length,
        itemBuilder: (context, index) {
          final charge = _pendingCharges[index];
          return _ChargeCard(
            charge: charge,
            onApprove: () => _approveCharge(charge['id'], true),
            onReject: () => _approveCharge(charge['id'], false),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              "충전 내역이 없습니다",
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final entry = _history[index];
          final isApproved = entry['status'] == 'approved';
          final isRejected = entry['status'] == 'rejected';
          final isPending = entry['status'] == 'pending';

          return Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withValues(alpha: 0.2)
                          : isRejected
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isApproved
                          ? Icons.check_circle
                          : isRejected
                              ? Icons.cancel
                              : Icons.hourglass_empty,
                      color: isApproved
                          ? Colors.green
                          : isRejected
                              ? Colors.red
                              : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${entry['amount']} DADA Point",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "사용자: ${entry['user_id'] ?? 'N/A'}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        Text(
                          "요청: ${entry['requested_at'] ?? 'N/A'}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                        if (entry['reason'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            "사유: ${entry['reason']}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withValues(alpha: 0.15)
                          : isRejected
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isApproved
                          ? "승인"
                          : isRejected
                              ? "거부"
                              : "대기",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isApproved
                            ? Colors.green
                            : isRejected
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  final Map<String, dynamic> charge;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ChargeCard({
    required this.charge,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Color(0xFF9F7AEA)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "사용자: ${charge['user_id'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "요청: ${charge['requested_at'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "대기",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // Amount
            Row(
              children: [
                const Text(
                  "충전 금액",
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const Spacer(),
                Text(
                  "${charge['amount']} DADA Point",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9F7AEA),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            if (charge['payment_method'] != null)
              Row(
                children: [
                  const Text(
                    "결제 방식",
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                  const Spacer(),
                  Text(
                    charge['payment_method'] == 'stripe' ? 'Stripe' : charge['payment_method'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text(
                        "승인",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text(
                        "거부",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
