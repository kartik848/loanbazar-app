import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/loan_model.dart';
import '../widgets/status_badge.dart';
import 'loan_status_screen.dart';
import 'apply_loan_screen.dart';

class MyLoansScreen extends StatelessWidget {
  const MyLoansScreen({super.key});

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
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final user = AuthService().currentUser;
    final userPhone = user?.phone ?? '';
    final userEmail = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('My Loan Portfolio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<LoanApplication>>(
        stream: FirestoreService.streamApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
          }

          final allApps = snapshot.data ?? [];
          final userLoans = userPhone.isNotEmpty || userEmail.isNotEmpty
              ? allApps.where((loan) => _matchesUser(loan, userPhone, userEmail)).toList()
              : allApps; // fallback if single session

          if (userLoans.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1E3A8A).withOpacity(0.08), const Color(0xFF3B82F6).withOpacity(0.12)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 56, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Active Loan Applications',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You do not have any pending or active loans. Check your credit limit and apply in 2 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        elevation: 2,
                        shadowColor: const Color(0xFF1E3A8A).withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('Apply for Instant Loan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen())),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeCount = userLoans.where((l) => l.status == 'disbursed' || l.status == 'approved' || l.status == 'acceptance_submitted' || l.status == 'acceptance_done').length;
          final totalBorrowings = userLoans.fold<double>(0, (sum, l) => sum + l.amount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // High-End Summary Metrics Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PORTFOLIO OVERVIEW', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF34D399)),
                          ),
                          child: Text('$activeCount Active Application${activeCount == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Total Applied / Sanctioned', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(totalBorrowings),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All Applications (${userLoans.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3A8A), padding: EdgeInsets.zero),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('New Loan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...userLoans.map((loan) {
                final isOverdue = loan.isOverdue;
                final totalPayable = loan.totalCurrentPayable;
                final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3)),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoanStatusScreen(applicationId: loan.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Loan Amount', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                  Text(
                                    currencyFormat.format(loan.amount),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                              StatusBadge(status: loan.status),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loan.status == 'disbursed'
                                          ? (isOverdue ? 'Total Overdue' : 'Current EMI')
                                          : (loan.tenureDays > 0 && loan.tenureMonths == 0 ? 'Bullet Due' : 'Monthly EMI'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyFormat.format(loan.status == 'disbursed' ? totalPayable : loan.monthlyEmi),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tenure Plan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text(loan.tenureDisplay, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              if (loan.status == 'disbursed')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoanStatusScreen(applicationId: loan.id),
                                      ),
                                    );
                                  },
                                  child: const Text('Pay EMI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                )
                              else if (loan.status == 'approved')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoanStatusScreen(applicationId: loan.id),
                                      ),
                                    );
                                  },
                                  child: const Text('Pay ₹1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${loan.bankName} ($maskedAcc)',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy').format(loan.createdAt),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
