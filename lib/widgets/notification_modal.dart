import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../screens/loan_status_screen.dart';

class NotificationModal {
  static void show(BuildContext context, List<AppNotificationItem> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF1E3A8A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notifications & Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(
                          notifications.isEmpty ? 'No new alerts' : '${notifications.length} active updates',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body List
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No Notifications Right Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          const Text('You are all caught up!', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final timeStr = DateFormat('dd MMM, hh:mm a').format(item.timestamp);

                        Color cardBg;
                        Color borderCol;
                        IconData iconData;
                        Color iconCol;

                        switch (item.type) {
                          case 'emi_overdue':
                            cardBg = const Color(0xFFFEF2F2);
                            borderCol = const Color(0xFFFECACA);
                            iconData = Icons.warning_rounded;
                            iconCol = const Color(0xFFDC2626);
                            break;
                          case 'emi_due':
                            cardBg = const Color(0xFFFFFBEB);
                            borderCol = const Color(0xFFFDE68A);
                            iconData = Icons.timer_rounded;
                            iconCol = const Color(0xFFD97706);
                            break;
                          case 'approved':
                            cardBg = const Color(0xFFF0FDF4);
                            borderCol = const Color(0xFFBBF7D0);
                            iconData = Icons.check_circle_rounded;
                            iconCol = const Color(0xFF16A34A);
                            break;
                          case 'disbursed':
                            cardBg = const Color(0xFFEFF6FF);
                            borderCol = const Color(0xFFBFDBFE);
                            iconData = Icons.account_balance_wallet_rounded;
                            iconCol = const Color(0xFF2563EB);
                            break;
                          case 'repaid':
                          default:
                            cardBg = const Color(0xFFF8FAFC);
                            borderCol = const Color(0xFFE2E8F0);
                            iconData = Icons.info_outline_rounded;
                            iconCol = const Color(0xFF64748B);
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: iconCol.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(iconData, size: 18, color: iconCol),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: item.type == 'emi_overdue' ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.message,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                              ),
                              if (item.applicationId != null) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: item.type == 'emi_overdue'
                                          ? const Color(0xFFDC2626)
                                          : (item.type == 'approved' ? const Color(0xFF16A34A) : const Color(0xFF1E3A8A)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LoanStatusScreen(applicationId: item.applicationId!),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      item.type == 'approved'
                                          ? 'Pay ₹1 & Accept Loan Offer'
                                          : (item.type == 'emi_overdue' || item.type == 'emi_due' ? 'Tap to Pay EMI' : 'View Loan Details'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
