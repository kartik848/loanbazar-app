import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/loan_model.dart';
import '../widgets/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isAuthenticated = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _authError = '';

  int _selectedViewTab = 0; // 0 = Applications, 1 = User Directory
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _userSearchQuery = '';

  void _handleLogin() {
    if (_emailController.text.trim() == 'admin@gmail.com' &&
        _passwordController.text == '123456') {
      setState(() {
        _isAuthenticated = true;
        _authError = '';
      });
    } else {
      setState(() {
        _authError = 'Invalid email or password. Please use admin@gmail.com / 123456';
      });
    }
  }

  void _handleLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  // 1. Approve Application
  Future<void> _approveApplication(LoanApplication app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Loan Application'),
        content: Text(
          'Approve loan application of ₹${app.amount.toInt()} for ${app.fullName}?\n\nThe applicant will be notified to pay ₹1 loan acceptance verification fee to disburse the loan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('applications').doc(app.id).update({
        'status': 'approved',
        'approvedBy': 'admin@gmail.com',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('Loan approved for ${app.fullName}!')),
        );
      }
    }
  }

  // 2. Reject Application
  Future<void> _rejectApplication(LoanApplication app) async {
    final reasonController = TextEditingController(text: 'Credit score or KYC criteria not met');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline / Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter reason for rejecting ${app.fullName}\'s application:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Rejection Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('applications').doc(app.id).update({
        'status': 'rejected',
        'rejectedBy': 'admin@gmail.com',
        'rejectionReason': reasonController.text.trim(),
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Application rejected for ${app.fullName}')),
        );
      }
    }
  }

  // 3. Disburse Loan
  Future<void> _disburseLoan(LoanApplication app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Loan Disbursal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disburse ₹${app.amount.toInt()} directly to applicant bank account?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank: ${app.bankName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Account: ${app.accountNumber}'),
                  Text('IFSC: ${app.ifscCode}'),
                  Text('Holder: ${app.accountHolderName.isNotEmpty ? app.accountHolderName : app.fullName}'),
                  if (app.razorpayPaymentId != null)
                    Text('AutoPay Mandate: ${app.razorpayPaymentId}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Mark Disbursed'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final now = DateTime.now();
      final due = app.tenureDays > 0 ? now.add(Duration(days: app.tenureDays)) : now.add(Duration(days: (app.tenureMonths > 0 ? app.tenureMonths : 1) * 30));

      await FirebaseFirestore.instance.collection('applications').doc(app.id).update({
        'status': 'disbursed',
        'disbursedBy': 'admin@gmail.com',
        'disbursedAt': FieldValue.serverTimestamp(),
        'nextEmiDueDate': Timestamp.fromDate(due),
        'dueDate': Timestamp.fromDate(due),
        'emisPaid': 0,
        'penaltyPerDay': 100.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('₹${app.amount.toInt()} marked Disbursed! User notified.')),
        );
      }
    }
  }

  // 3.1. Approve ₹1 Verification Payment
  Future<void> _approveAcceptance(LoanApplication app) async {
    final utr = app.acceptancePaymentId ?? app.razorpayPaymentId ?? 'N/A';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve ₹1 Verification Payment'),
        content: Text('Applicant: ${app.fullName}\nSubmitted UTR: $utr\n\nHave you verified ₹1 in Razorpay/Bank statement?\nApproving enables immediate loan disbursal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('✓ Payment Received (Approve)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('applications').doc(app.id).update({
      'status': 'acceptance_done',
      'acceptanceFeePaid': true,
      'acceptancePaidAt': FieldValue.serverTimestamp(),
      'acceptanceRejectReason': FieldValue.delete(),
    });

    final repSnap = await FirebaseFirestore.instance.collection('repayments').where('applicationId', isEqualTo: app.id).get();
    for (var d in repSnap.docs) {
      if (d.data()['type'] == 'acceptance_fee') {
        await d.reference.update({'status': 'verified', 'verifiedAt': FieldValue.serverTimestamp()});
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('₹1 Payment verified for ${app.fullName}! Ready to disburse.')),
      );
    }
  }

  // 3.2. Reject ₹1 Verification Payment
  Future<void> _rejectAcceptance(LoanApplication app) async {
    final controller = TextEditingController(text: 'Payment not received in Razorpay account / Invalid UTR reference');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject ₹1 Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${app.fullName}\nSubmitted UTR: ${app.acceptancePaymentId ?? "N/A"}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Rejection Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('✕ Reject Payment'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final reason = controller.text.trim();
    await FirebaseFirestore.instance.collection('applications').doc(app.id).update({
      'status': 'approved',
      'acceptanceFeePaid': false,
      'acceptancePaymentId': FieldValue.delete(),
      'acceptanceRejectReason': reason.isNotEmpty ? reason : 'Invalid UTR reference / payment not received',
    });

    final repSnap = await FirebaseFirestore.instance.collection('repayments').where('applicationId', isEqualTo: app.id).get();
    for (var d in repSnap.docs) {
      if (d.data()['type'] == 'acceptance_fee') {
        await d.reference.update({'status': 'rejected', 'rejectedReason': reason});
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('₹1 Payment rejected for ${app.fullName}. User notified.')),
      );
    }
  }

  // 4. Block / Unblock User
  Future<void> _toggleBlockUser(String phone, bool currentBlocked) async {
    final action = currentBlocked ? 'Unblock' : 'Block';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User'),
        content: Text('Are you sure you want to $action user with phone +91 $phone across the platform?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentBlocked ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm $action'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final snaps = await FirebaseFirestore.instance
          .collection('applications')
          .where('userPhone', isEqualTo: phone)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var d in snaps.docs) {
        batch.update(d.reference, {'isBlocked': !currentBlocked});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User (+91 $phone) is now ${!currentBlocked ? "Blocked" : "Active"}')),
        );
      }
    }
  }

  // 5. Delete Application
  Future<void> _deleteApplication(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Application Record'),
        content: const Text('Permanently delete this loan application record from the database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('applications').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application record deleted.')),
        );
      }
    }
  }

  // 6. View Document Modal
  void _openDocumentModal(String title, String? url) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document uploaded for this applicant.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 380),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Preview unavailable. Use download button below.'),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open / Download'),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildLoginView();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SvgPicture.asset(
                'assets/images/logo.svg',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Loan Bazar - Admin Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout Admin',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBarHeader(
          selectedTab: _selectedViewTab,
          onTabChanged: (idx) => setState(() => _selectedViewTab = idx),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('applications').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final allApps = docs.map((d) => LoanApplication.fromFirestore(d)).toList();

          if (_selectedViewTab == 0) {
            return _buildApplicationsView(allApps);
          } else {
            return _buildUsersDirectoryView(allApps);
          }
        },
      ),
    );
  }

  // Login View
  Widget _buildLoginView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SvgPicture.asset(
                          'assets/images/logo.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Loan Bazar Master Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Sign in to manage loans & disbursals', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 20),
                    if (_authError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_authError, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Admin Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _handleLogin,
                        child: const Text('Log In to Admin Console', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Applications Tab View
  Widget _buildApplicationsView(List<LoanApplication> allApps) {
    // KPI Metrics
    final totalCount = allApps.length;
    final underReviewCount = allApps.where((a) => a.status == 'under_review').length;
    final pendingAcceptanceCount = allApps.where((a) => a.status == 'acceptance_submitted').length;
    final acceptedCount = allApps.where((a) => a.status == 'acceptance_done' || a.status == 'autopay_done').length;
    final disbursedTotal = allApps.where((a) => a.status == 'disbursed').fold<double>(0, (s, a) => s + a.amount);

    final filtered = allApps.where((app) {
      final matchesSearch = app.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.userPhone.contains(_searchQuery) ||
          app.panNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.bankName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.accountNumber.contains(_searchQuery) ||
          (app.razorpayPaymentId ?? '').contains(_searchQuery) ||
          (app.acceptancePaymentId ?? '').contains(_searchQuery);

      final matchesStatus = _statusFilter == 'all' ||
          app.status == _statusFilter ||
          (_statusFilter == 'acceptance_done' && (app.status == 'acceptance_done' || app.status == 'autopay_done'));
      return matchesSearch && matchesStatus;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI Grid
        Row(
          children: [
            _buildKpiCard('Total Applications', '$totalCount', Icons.assignment, Colors.blue),
            const SizedBox(width: 10),
            _buildKpiCard('Under Review', '$underReviewCount', Icons.hourglass_top, Colors.amber),
            const SizedBox(width: 10),
            _buildKpiCard('⚡ ₹1 Pending', '$pendingAcceptanceCount', Icons.pending_actions, Colors.orange),
            const SizedBox(width: 10),
            _buildKpiCard('Ready to Disburse', '$acceptedCount', Icons.verified, Colors.purple),
            const SizedBox(width: 10),
            _buildKpiCard('Disbursed Capital', '₹${disbursedTotal.toInt()}', Icons.account_balance_wallet, Colors.green),
          ],
        ),
        const SizedBox(height: 16),

        // Filter and Search Header
        TextField(
          decoration: InputDecoration(
            hintText: '🔍 Search by name, phone, PAN, bank account, or UTR / payment ID...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              _buildFilterChip('Under Review', 'under_review'),
              _buildFilterChip('Approved (Waiting ₹1)', 'approved'),
              _buildFilterChip('⚡ ₹1 Review ($pendingAcceptanceCount)', 'acceptance_submitted'),
              _buildFilterChip('₹1 Verified (Ready)', 'acceptance_done'),
              _buildFilterChip('Disbursed', 'disbursed'),
              _buildFilterChip('Rejected', 'rejected'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Applications List
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No loan applications found matching filters.')),
            ),
          )
        else
          ...filtered.map((app) => _buildApplicationCard(app)),
      ],
    );
  }

  Widget _buildApplicationCard(LoanApplication app) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: app.isBlocked ? Colors.red.shade300 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Name + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF1E3A8A),
                        child: Text(
                          app.fullName.isNotEmpty ? app.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('📱 +91 ${app.userPhone} | ✉️ ${app.userEmail}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: app.status),
              ],
            ),
            const Divider(height: 20),

            // Middle Section: Financials & Bank Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financials Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Loan Request', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        const SizedBox(height: 4),
                        Text('Amount: ₹${app.amount.toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('EMI: ₹${app.monthlyEmi.toStringAsFixed(2)} / mo'),
                        Text('Tenure: ${app.tenureMonths} Mos @ ${app.interestRate}% p.a.'),
                        Text('PAN: ${app.panNumber.isNotEmpty ? app.panNumber : "N/A"}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Bank Details Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Disbursal Bank', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Bank: ${app.bankName.isNotEmpty ? app.bankName : "Not specified"}'),
                        Text('A/C: ${app.accountNumber.isNotEmpty ? app.accountNumber : "—"}'),
                        Text('IFSC: ${app.ifscCode.isNotEmpty ? app.ifscCode : "—"}'),
                        if (app.acceptancePaymentId != null || app.razorpayPaymentId != null)
                          Text('₹1 Verified Ref: ${app.acceptancePaymentId ?? app.razorpayPaymentId}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Document View Buttons Grid
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildDocButton('📄 PAN Card', app.panUrl),
                _buildDocButton('🆔 Aadhaar', app.aadhaarUrl),
                _buildDocButton('💼 Salary Slip', app.incomeProofUrl),
                _buildDocButton('🏦 Statement', app.bankStatementUrl),
              ],
            ),
            const Divider(height: 20),

            // Bottom Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Block/Delete quick buttons
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(app.isBlocked ? Icons.lock_open : Icons.block, size: 16, color: app.isBlocked ? Colors.green : Colors.orange),
                      label: Text(app.isBlocked ? 'Unblock' : 'Block User', style: TextStyle(color: app.isBlocked ? Colors.green : Colors.orange, fontSize: 12)),
                      onPressed: () => _toggleBlockUser(app.userPhone, app.isBlocked),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Delete Record',
                      onPressed: () => _deleteApplication(app.id),
                    ),
                  ],
                ),

                // Primary Workflow Buttons
                if (app.status == 'under_review') ...[
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        onPressed: () => _rejectApplication(app),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _approveApplication(app),
                        child: const Text('Approve Loan'),
                      ),
                    ],
                  ),
                ] else if (app.status == 'acceptance_submitted') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
                        child: Text('⚡ UTR: ${app.acceptancePaymentId ?? "N/A"}', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () => _rejectAcceptance(app),
                            child: const Text('✕ Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _approveAcceptance(app),
                            child: const Text('✓ Received (Approve ₹1)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else if (app.status == 'acceptance_done' || app.status == 'autopay_done') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: Text('Disburse ₹${app.amount.toInt()} to ${app.bankName}'),
                    onPressed: () => _disburseLoan(app),
                  ),
                ] else if (app.status == 'approved') ...[
                  const Text('Waiting for user to pay ₹1 & submit UTR in App', style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                ] else if (app.status == 'disbursed') ...[
                  const Text('✓ Disbursed & Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ] else if (app.status == 'rejected') ...[
                  Text('Declined: ${app.rejectionReason ?? "Criteria not met"}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocButton(String label, String? url) {
    final hasDoc = url != null && url.isNotEmpty;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: hasDoc ? Colors.blue.shade300 : Colors.grey.shade300),
        backgroundColor: hasDoc ? Colors.blue.shade50 : Colors.grey.shade50,
      ),
      icon: Icon(hasDoc ? Icons.visibility : Icons.visibility_off, size: 14, color: hasDoc ? Colors.blue.shade700 : Colors.grey),
      label: Text(label, style: TextStyle(fontSize: 11, color: hasDoc ? Colors.blue.shade900 : Colors.grey)),
      onPressed: () => _openDocumentModal(label, url),
    );
  }

  // Users Directory Tab View
  Widget _buildUsersDirectoryView(List<LoanApplication> allApps) {
    final usersMap = <String, Map<String, dynamic>>{};
    for (var app in allApps) {
      final key = app.userPhone.isNotEmpty ? app.userPhone : app.fullName;
      if (!usersMap.containsKey(key)) {
        usersMap[key] = {
          'name': app.fullName,
          'phone': app.userPhone,
          'email': app.userEmail,
          'pan': app.panNumber,
          'aadhaar': app.aadhaarNumber,
          'bankName': app.bankName,
          'accountNumber': app.accountNumber,
          'isBlocked': app.isBlocked,
          'totalLoans': 1,
          'totalAmount': app.amount,
          'apps': [app],
        };
      } else {
        usersMap[key]!['totalLoans'] += 1;
        usersMap[key]!['totalAmount'] += app.amount;
        (usersMap[key]!['apps'] as List).add(app);
        if (app.isBlocked) usersMap[key]!['isBlocked'] = true;
      }
    }

    final usersList = usersMap.values.where((u) {
      return (u['name'] as String).toLowerCase().contains(_userSearchQuery.toLowerCase()) ||
          (u['phone'] as String).contains(_userSearchQuery) ||
          (u['pan'] as String).toLowerCase().contains(_userSearchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: '🔍 Search users by name, mobile, PAN...',
            prefixIcon: const Icon(Icons.person_search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (val) => setState(() => _userSearchQuery = val),
        ),
        const SizedBox(height: 16),
        ...usersList.map((user) {
          final isBlocked = user['isBlocked'] as bool;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isBlocked ? Colors.red.shade100 : Colors.blue.shade100,
                child: Text(
                  (user['name'] as String).isNotEmpty ? user['name'][0].toUpperCase() : 'U',
                  style: TextStyle(color: isBlocked ? Colors.red : const Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('📱 +91 ${user['phone']} | Total Loans: ${user['totalLoans']} (₹${(user['totalAmount'] as double).toInt()})\nBank: ${user['bankName']} (A/C: ${user['accountNumber']})'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBlocked ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _toggleBlockUser(user['phone'], isBlocked),
                child: Text(isBlocked ? 'Unblock' : 'Block'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
        selected: isSelected,
        selectedColor: const Color(0xFF1E3A8A),
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }
}

class TabBarHeader extends StatelessWidget implements PreferredSizeWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const TabBarHeader({super.key, required this.selectedTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onTabChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selectedTab == 0 ? const Color(0xFF38BDF8) : Colors.transparent, width: 3)),
                ),
                child: Center(
                  child: Text(
                    '📋 Loan Applications',
                    style: TextStyle(color: selectedTab == 0 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onTabChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selectedTab == 1 ? const Color(0xFF38BDF8) : Colors.transparent, width: 3)),
                ),
                child: Center(
                  child: Text(
                    '👥 User Directory',
                    style: TextStyle(color: selectedTab == 1 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);
}
