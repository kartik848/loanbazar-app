import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/loan_model.dart';
import '../widgets/support_modal.dart';
import '../widgets/notification_modal.dart';
import 'apply_loan_screen.dart';
import 'loan_status_screen.dart';
import 'my_loans_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeDashboard(),
    const ApplyLoanScreen(),
    const MyLoansScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xFF1E3A8A),
            selectedIndex: _currentIndex,
            height: 65,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined, color: Colors.white70), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF38BDF8)), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded, color: Colors.white70), selectedIcon: Icon(Icons.add_circle_rounded, color: Color(0xFF38BDF8)), label: 'Apply'),
              NavigationDestination(icon: Icon(Icons.history_rounded, color: Colors.white70), selectedIcon: Icon(Icons.history_toggle_off_rounded, color: Color(0xFF38BDF8)), label: 'My Loans'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded, color: Colors.white70), selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF38BDF8)), label: 'Account'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  bool _matchesUser(LoanApplication loan, String userPhone, String userEmail) {
    final cleanUserP = userPhone.replaceAll(RegExp(r'\D'), '');
    final cleanLoanP = loan.userPhone.replaceAll(RegExp(r'\D'), '');

    if (cleanUserP.isNotEmpty && cleanLoanP.isNotEmpty) {
      if (cleanUserP == cleanLoanP) return true;
      final u10 = cleanUserP.length >= 10 ? cleanUserP.substring(cleanUserP.length - 10) : cleanUserP;
      final l10 = cleanLoanP.length >= 10 ? cleanLoanP.substring(cleanLoanP.length - 10) : cleanLoanP;
      if (u10 == l10) return true;
    }

    if (userEmail.trim().isNotEmpty && loan.userEmail.trim().isNotEmpty) {
      if (userEmail.trim().toLowerCase() == loan.userEmail.trim().toLowerCase()) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final userName = user?.name.split(' ').first ?? 'Customer';
    final userPhone = user?.phone ?? '';
    final userEmail = user?.email ?? '';
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SvgPicture.asset(
                  'assets/images/logo_mark.svg',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontFamily: 'Roboto',
                ),
                children: [
                  TextSpan(text: 'LOAN ', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'BAZAR', style: TextStyle(color: Color(0xFFF59E0B))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<List<LoanApplication>>(
            stream: FirestoreService.streamApplications(),
            builder: (context, snapshot) {
              final allApps = snapshot.data ?? [];
              final userApps = userPhone.isNotEmpty || userEmail.isNotEmpty
                  ? allApps.where((a) => _matchesUser(a, userPhone, userEmail)).toList()
                  : allApps;
              final notifications = NotificationService.generateNotificationsFromLoans(userApps);
              final hasUrgent = notifications.any((n) => n.isUrgent);

              return IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(),
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    if (notifications.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: hasUrgent ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                          child: Text(
                            '${notifications.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => NotificationModal.show(context, notifications),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 14, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF059669).withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 12),
                SizedBox(width: 4),
                Text(
                  'Secured NBFC ✓',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<List<LoanApplication>>(
            stream: FirestoreService.streamApplications(),
            builder: (context, snapshot) {
              final allApps = snapshot.data ?? [];
              final userApps = userPhone.isNotEmpty || userEmail.isNotEmpty
                  ? allApps.where((a) => _matchesUser(a, userPhone, userEmail)).toList()
                  : allApps;

              if (userApps.isEmpty) return const SizedBox.shrink();

              final activeLoans = userApps.where((a) =>
                  a.status == 'disbursed' ||
                  a.status == 'approved' ||
                  a.status == 'acceptance_submitted' ||
                  a.status == 'acceptance_done').toList();

              if (activeLoans.isEmpty) return const SizedBox.shrink();

              return Column(
                children: activeLoans.map((loan) {
                  if (loan.status == 'disbursed') {
                    final daysOverdue = loan.daysOverdue;
                    final isOverdue = loan.isOverdue;
                    final penalty = loan.currentPenalty;
                    final totalPayable = loan.totalCurrentPayable;
                    final dueDateStr = dateFormat.format(loan.effectiveDueDate);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOverdue
                              ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B), const Color(0xFFB91C1C)]
                              : [const Color(0xFF0F172A), const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isOverdue ? Colors.red : const Color(0xFF1E3A8A)).withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                      child: Icon(
                                        isOverdue ? Icons.warning_rounded : Icons.payments_rounded,
                                        color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFF38BDF8),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        isOverdue ? '⚠️ EMI OVERDUE ($daysOverdue DAYS)' : '⚡ LIVE REPAYMENT DUE',
                                        style: TextStyle(
                                          color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFF38BDF8),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Due: $dueDateStr',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isOverdue ? 'Total Due (EMI + Penalty)' : 'Total Due Amount',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyFormat.format(totalPayable),
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                    ),
                                    if (isOverdue) ...[
                                      Text(
                                        'Base: ${currencyFormat.format(loan.monthlyEmi)} + Late: ${currencyFormat.format(penalty)}',
                                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOverdue ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                  foregroundColor: isOverdue ? Colors.white : const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Pay EMI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LoanStatusScreen(applicationId: loan.id),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFFDE68A), size: 13),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '⚠️ Note: ₹100/day penalty accumulates on overdue balance until settled.',
                                    style: TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (loan.status == 'approved') {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🎉 Loan Offer Approved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('Pay ₹1 verification to disburse ${currencyFormat.format(loan.amount)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF065F46),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoanStatusScreen(applicationId: loan.id),
                                ),
                              );
                            },
                            child: const Text('Pay ₹1', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }

                  if (loan.status == 'acceptance_submitted') {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFD97706).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⚡ ₹1 Verification Submitted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  'Verifying for ${currencyFormat.format(loan.amount)}. Disbursal in progress.',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF92400E),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LoanStatusScreen(applicationId: loan.id)),
                              );
                            },
                            child: const Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }

                  if (loan.status == 'acceptance_done' || loan.status == 'autopay_done') {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '₹1 Verified for ${currencyFormat.format(loan.amount)}. Admin disbursal in queue.',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                }).toList(),
              );
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF334155), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.4),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.memory_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, $userName 👋',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Pre-Approved Credit Line',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 14),
                          SizedBox(width: 3),
                          Text('INSTANT', style: TextStyle(color: Color(0xFFFCD34D), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Credit Limit', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text(
                          '₹1,00,000',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Text('100% Available', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                          shadowColor: const Color(0xFFF59E0B).withOpacity(0.4),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Apply Loan Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('My Loans', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLoansScreen())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Instant Financial Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2)),
              Text('Fast • Paperless', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            children: [
              _buildServiceItem(context, Icons.electric_bolt_rounded, 'Instant\nCash', const Color(0xFFF59E0B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen()))),
              _buildServiceItem(context, Icons.business_center_rounded, 'Business\nLoan', const Color(0xFF3B82F6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen()))),
              _buildServiceItem(context, Icons.account_balance_rounded, 'Personal\nLoan', const Color(0xFF10B981), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen()))),
              _buildServiceItem(context, Icons.support_agent_rounded, '24x7\nSupport', const Color(0xFF8B5CF6), () => SupportModal.show(context)),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trust & Governance Highlights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                _buildTrustRow(Icons.security_rounded, 'RBI Registered NBFC Partners', 'Compliant with digital lending norms & fair practices'),
                const SizedBox(height: 12),
                _buildTrustRow(Icons.flash_on_rounded, '100% Automated Disbursals', 'Direct IMPS/NEFT bank transfer post ₹1 acceptance verification'),
                const SizedBox(height: 12),
                _buildTrustRow(Icons.lock_outline_rounded, '256-Bit SSL Bank Grade Security', 'Your documents, PAN & KYC are fully encrypted end-to-end'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A8A), size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
