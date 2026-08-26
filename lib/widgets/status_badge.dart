import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgGradientStart;
    Color bgGradientEnd;
    Color fg;
    Color borderColor;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        bgGradientStart = const Color(0xFFFEF3C7);
        bgGradientEnd = const Color(0xFFFDE68A);
        fg = const Color(0xFFB45309);
        borderColor = const Color(0xFFF59E0B);
        label = 'Offer Approved';
        icon = Icons.verified_rounded;
        break;
      case 'acceptance_submitted':
        bgGradientStart = const Color(0xFFFFF7ED);
        bgGradientEnd = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        borderColor = const Color(0xFFEA580C);
        label = '₹1 Under Review';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'acceptance_done':
      case 'autopay_done':
        bgGradientStart = const Color(0xFFEFF6FF);
        bgGradientEnd = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        borderColor = const Color(0xFF3B82F6);
        label = '₹1 Verified (Ready)';
        icon = Icons.check_circle_rounded;
        break;
      case 'disbursed':
        bgGradientStart = const Color(0xFFECFDF5);
        bgGradientEnd = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        borderColor = const Color(0xFF10B981);
        label = 'Disbursed (Active)';
        icon = Icons.account_balance_wallet_rounded;
        break;
      case 'repaid':
      case 'completed':
        bgGradientStart = const Color(0xFFF0FDF4);
        bgGradientEnd = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        borderColor = const Color(0xFF22C55E);
        label = 'Loan Repaid ✓';
        icon = Icons.task_alt_rounded;
        break;
      case 'rejected':
        bgGradientStart = const Color(0xFFFEF2F2);
        bgGradientEnd = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        borderColor = const Color(0xFFEF4444);
        label = 'Declined';
        icon = Icons.cancel_rounded;
        break;
      case 'under_review':
      default:
        bgGradientStart = const Color(0xFFFFFBEB);
        bgGradientEnd = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        borderColor = const Color(0xFFFBBF24);
        label = 'Under Review';
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgGradientStart, bgGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

