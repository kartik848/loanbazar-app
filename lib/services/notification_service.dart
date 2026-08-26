import 'package:intl/intl.dart';
import '../models/loan_model.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'emi_due' | 'emi_overdue' | 'approved' | 'disbursed' | 'repaid' | 'info'
  final DateTime timestamp;
  final bool isUrgent;
  final String? applicationId;
  final double? amount;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isUrgent = false,
    this.applicationId,
    this.amount,
  });
}

class NotificationService {
  static final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  /// Generates dynamic notifications from real-time loan applications
  static List<AppNotificationItem> generateNotificationsFromLoans(List<LoanApplication> loans) {
    final List<AppNotificationItem> list = [];

    for (final loan in loans) {
      if (loan.status == 'approved') {
        list.add(AppNotificationItem(
          id: 'notif_approved_${loan.id}',
          title: '🎉 Loan Approved - Pay ₹1 to Disburse',
          message: 'Congratulations! Your loan offer of ${_currency.format(loan.amount)} @ ${loan.interestRate}% is approved. Pay ₹1 acceptance verification fee to receive funds in your bank.',
          type: 'approved',
          timestamp: loan.approvedAt ?? loan.createdAt,
          isUrgent: true,
          applicationId: loan.id,
          amount: 1.0,
        ));
      } else if (loan.status == 'disbursed') {
        final daysOverdue = loan.daysOverdue;
        final dueDate = loan.effectiveDueDate;
        final totalPayable = loan.totalCurrentPayable;

        if (daysOverdue > 0) {
          list.add(AppNotificationItem(
            id: 'notif_overdue_${loan.id}_$daysOverdue',
            title: '🚨 Urgent: EMI Overdue by $daysOverdue Day${daysOverdue > 1 ? "s" : ""}',
            message: 'Your EMI of ${_currency.format(loan.monthlyEmi)} was due on ${_dateFormat.format(dueDate)}. Late penalty of ₹${daysOverdue * 100} has been added. Total payable: ${_currency.format(totalPayable)}. Tap to pay now to avoid further ₹100/day penalty.',
            type: 'emi_overdue',
            timestamp: DateTime.now(),
            isUrgent: true,
            applicationId: loan.id,
            amount: totalPayable,
          ));
        } else {
          final now = DateTime.now();
          final diffDays = dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
          if (diffDays <= 5) {
            list.add(AppNotificationItem(
              id: 'notif_due_soon_${loan.id}',
              title: diffDays == 0 ? '⏰ EMI Due Today!' : '⏰ EMI Due in $diffDays Day${diffDays > 1 ? "s" : ""}',
              message: 'Your upcoming EMI of ${_currency.format(loan.monthlyEmi)} for Loan #${loan.id.substring(0, loan.id.length > 6 ? 6 : loan.id.length)} is due on ${_dateFormat.format(dueDate)}. Pay on time to avoid ₹100/day penalty.',
              type: 'emi_due',
              timestamp: loan.disbursedAt ?? loan.createdAt,
              isUrgent: diffDays <= 1,
              applicationId: loan.id,
              amount: loan.monthlyEmi,
            ));
          }

          final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;
          list.add(AppNotificationItem(
            id: 'notif_disbursed_${loan.id}',
            title: '💰 Funds Disbursed to Bank',
            message: '${_currency.format(loan.netDisbursalAmount > 0 ? loan.netDisbursalAmount : loan.amount)} successfully credited to ${loan.bankName} (A/C: $maskedAcc).',
            type: 'disbursed',
            timestamp: loan.disbursedAt ?? loan.createdAt,
            applicationId: loan.id,
            amount: loan.netDisbursalAmount,
          ));
        }
      } else if (loan.status == 'repaid' || loan.status == 'completed') {
        list.add(AppNotificationItem(
          id: 'notif_repaid_${loan.id}',
          title: '✅ Loan Successfully Repaid',
          message: 'Thank you for your timely repayment! Your loan of ${_currency.format(loan.amount)} has been closed successfully. You are eligible for higher credit limits.',
          type: 'repaid',
          timestamp: loan.disbursedAt ?? loan.createdAt,
          applicationId: loan.id,
          amount: loan.amount,
        ));
      }
    }

    return list;
  }
}
