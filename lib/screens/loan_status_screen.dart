import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/loan_model.dart';

class LoanStatusScreen extends StatefulWidget {
  final String applicationId;
  const LoanStatusScreen({super.key, required this.applicationId});

  @override
  State<LoanStatusScreen> createState() => _LoanStatusScreenState();
}

class _LoanStatusScreenState extends State<LoanStatusScreen> {
  bool _userOfferConsentChecked = false;
  bool _isProcessingPayment = false;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  static const String _razorpayPaymentUrl = 'https://razorpay.me/@mrugeshjaykumarchauhan';

  @override
  void initState() {
    super.initState();
  }

  // 1. Mark ₹1 Acceptance Paid & Ready for Disbursal (Fully Automated)
  Future<void> _markLoanAccepted(String paymentId) async {
    setState(() => _isProcessingPayment = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('applications').doc(widget.applicationId);
      final docSnap = await docRef.get();
      final data = docSnap.exists ? docSnap.data()! : <String, dynamic>{};

      final acceptanceRecord = {
        'applicationId': widget.applicationId,
        'paymentId': paymentId,
        'amount': 1.0,
        'type': 'acceptance_fee',
        'userName': data['fullName'] ?? 'Borrower',
        'userPhone': data['userPhone'] ?? '',
        'paidAt': FieldValue.serverTimestamp(),
        'method': 'razorpay',
        'status': 'pending_verification',
      };

      // 1. Log in subcollection
      await docRef.collection('repayments').add(acceptanceRecord);
      // 2. Log in global collection for instant Admin live stream
      await FirebaseFirestore.instance.collection('repayments').add(acceptanceRecord);

      // 3. Update application status to acceptance_submitted (awaiting admin approval)
      await docRef.update({
        'status': 'acceptance_submitted',
        'userConsentApproved': true,
        'autoPayConsentAccepted': true,
        'acceptanceFeePaid': false,
        'acceptancePaymentId': paymentId,
        'acceptanceSubmittedAt': FieldValue.serverTimestamp(),
        'acceptanceRejectReason': FieldValue.delete(),
        'razorpayPaymentId': paymentId,
      });

      if (mounted) {
        _showAcceptanceThankYouDialog(paymentId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error submitting verification: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  // 2. Mark EMI Repaid (Submitted for Admin Verification)
  Future<void> _markEmiRepaid(String paymentId, double amountPaid) async {
    setState(() => _isProcessingPayment = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('applications').doc(widget.applicationId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      final baseEmi = (data['monthlyEmi'] as num?)?.toDouble() ?? 0.0;
      final penaltyPaid = amountPaid > baseEmi ? (amountPaid - baseEmi) : 0.0;
      final tMonths = (data['tenureMonths'] as num?)?.toInt() ?? 0;
      final tDays = (data['tenureDays'] as num?)?.toInt() ?? 0;
      final isShortTerm = (tDays == 7 || tDays == 15 || (tDays > 0 && tMonths == 0) || tMonths <= 1);
      final currentEmisPaid = (data['emisPaid'] as num?)?.toInt() ?? 0;
      final newEmisPaid = currentEmisPaid + 1;
      final totalEmis = (data['totalEmis'] as num?)?.toInt() ?? (tMonths > 0 ? tMonths : 1);
      final bool isFullyPaid = isShortTerm || (newEmisPaid >= totalEmis);

      final repaymentRecord = {
        'applicationId': widget.applicationId,
        'paymentId': paymentId,
        'amount': amountPaid,
        'baseEmi': baseEmi,
        'penaltyPaid': penaltyPaid,
        'emiNumber': newEmisPaid,
        'totalEmis': totalEmis,
        'userName': data['fullName'] ?? 'Borrower',
        'userPhone': data['userPhone'] ?? '',
        'panNumber': data['panNumber'] ?? '',
        'paidAt': FieldValue.serverTimestamp(),
        'method': 'razorpay',
        'status': 'pending_verification',
        'isFinalSettlement': isFullyPaid,
      };

      // 1. Record in application repayments subcollection
      await docRef.collection('repayments').add(repaymentRecord);

      // 2. Record in global repayments collection for real-time Admin sync
      await FirebaseFirestore.instance.collection('repayments').add(repaymentRecord);

      // 3. Update application document with pending EMI verification
      await docRef.update({
        'pendingEmiPaymentId': paymentId,
        'pendingEmiAmount': amountPaid,
        'pendingEmiSubmittedAt': FieldValue.serverTimestamp(),
        'pendingEmiRejectReason': FieldValue.delete(),
      });

      if (mounted) {
        _showThankYouReceiptDialog(
          paymentId: paymentId,
          totalAmount: amountPaid,
          baseEmi: baseEmi > 0 ? baseEmi : amountPaid,
          penaltyPaid: penaltyPaid,
          emiNumber: newEmisPaid,
          totalEmis: totalEmis,
          isFullyPaid: isFullyPaid,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Repayment submission error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  // Thank You & Digital Payment Receipt Dialog (Verification Pending)
  void _showThankYouReceiptDialog({
    required String paymentId,
    required double totalAmount,
    required double baseEmi,
    required double penaltyPaid,
    required int emiNumber,
    required int totalEmis,
    required bool isFullyPaid,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 36),
              ),
              const SizedBox(height: 10),
              const Text(
                'Payment Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your EMI payment proof has been submitted to the admin team. Once verified with the bank, your loan schedule will update automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 14),

              // Digital Receipt Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Submitted Amount:', _currencyFormat.format(totalAmount), isBold: true, isHighlight: true),
                    const Divider(height: 12),
                    _buildModalRow('Principal Base EMI:', _currencyFormat.format(baseEmi)),
                    if (penaltyPaid > 0) ...[
                      const SizedBox(height: 4),
                      _buildModalRow('Late Penalty Paid:', '+${_currencyFormat.format(penaltyPaid)}', isBold: true, customColor: const Color(0xFFDC2626)),
                    ],
                    const SizedBox(height: 4),
                    _buildModalRow('Repayment Type:', isFullyPaid ? '🏆 Full Settlement' : 'EMI #$emiNumber of $totalEmis'),
                    const SizedBox(height: 4),
                    _buildModalRow('Payment ID / UTR:', paymentId.length > 14 ? '${paymentId.substring(0, 14)}...' : paymentId),
                    const SizedBox(height: 4),
                    _buildModalRow('Date & Time:', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
                    const SizedBox(height: 4),
                    _buildModalRow('Verification Status:', '⏳ Pending Admin Review', isBold: true, customColor: const Color(0xFFD97706)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done / View Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Acceptance Thank You Dialog (Verification Pending)
  void _showAcceptanceThankYouDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 36),
              ),
              const SizedBox(height: 10),
              const Text(
                '₹1 Verification Submitted!',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your ₹1 verification payment proof has been submitted. The admin credit team is verifying the payment. Bank disbursal will begin as soon as it is approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Verification Fee:', '₹1.00', isBold: true, isHighlight: true),
                    const SizedBox(height: 4),
                    _buildModalRow('Submitted UTR / Ref:', paymentId.length > 14 ? '${paymentId.substring(0, 14)}...' : paymentId),
                    const SizedBox(height: 4),
                    _buildModalRow('Verification Status:', '⏳ Under Review by Admin', isBold: true, customColor: const Color(0xFFD97706)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Track Application Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Open Razorpay payment link directly in browser / UPI app
  Future<void> _openExternalRazorpayLink(double amount, String paymentType) async {
    final formattedAmount = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    const urlStr = _razorpayPaymentUrl;
    final uri = Uri.parse(urlStr);

    await Clipboard.setData(ClipboardData(text: formattedAmount));

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }

    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E3A8A),
          content: Text(opened
              ? 'Opening Razorpay payment page (Pay ₹$formattedAmount)...'
              : 'Amount ₹$formattedAmount copied! Opening payment page...'),
          duration: const Duration(seconds: 3),
        ),
      );
      _showUtrSubmissionDialog(amount, paymentType);
    }
  }

  // Payment Confirmation & UTR Verification Dialog
  void _showUtrSubmissionDialog(double amount, String paymentType) {
    final utrController = TextEditingController();
    final formattedAmt = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final isAcceptance = paymentType == 'acceptance';
    const urlStr = _razorpayPaymentUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAcceptance
                            ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                            : [const Color(0xFF047857), const Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isAcceptance ? const Color(0xFF2563EB) : const Color(0xFF10B981)).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isAcceptance ? Icons.verified_user_rounded : Icons.payments_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAcceptance ? 'Confirm ₹1 Verification' : 'Confirm EMI Repayment',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            'Amount: ₹$formattedAmt',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 6),
                        Text('Payment Instructions:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A))),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text('1. Complete payment on Razorpay page via UPI, Card, Net Banking or Wallet.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                    SizedBox(height: 2),
                    Text('2. Copy 12-digit UPI Reference / UTR Number or Payment ID.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                    SizedBox(height: 2),
                    Text('3. Paste below & tap "Submit for Verification" to notify admin desk.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: utrController,
                autofocus: false,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Payment ID / UPI UTR / Reference No.',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  hintText: 'e.g. 423819827361 or pay_xxxxx',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E3A8A)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 2,
                    shadowColor: const Color(0xFF1E3A8A).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Submit for Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  onPressed: () {
                    final utr = utrController.text.trim();
                    if (utr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.red, content: Text('Please enter Payment ID or UTR number')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    if (isAcceptance) {
                      _markLoanAccepted(utr);
                    } else {
                      _markEmiRepaid(utr, amount);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open Payment Page', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final u = Uri.parse(urlStr);
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(text: urlStr));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF059669),
                              content: Text('Payment link copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Acceptance BottomSheet Modal (₹1 Loan Acceptance Fee)
  void _showAcceptanceModal(Map<String, dynamic> data) {
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final emi = (data['monthlyEmi'] as num?)?.toDouble() ?? 0.0;
    final rate = (data['interestRate'] as num?)?.toDouble() ?? 14.0;
    final bank = data['bankName'] ?? 'Bank Account';
    final acc = data['accountNumber'] ?? '';
    final maskedAcc = acc.length > 4 ? '****${acc.substring(acc.length - 4)}' : acc;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accept Loan Offer',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Pay ₹1 verification to confirm disbursal into $bank',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Approved Loan Amount:', _currencyFormat.format(amt), isBold: true),
                    const SizedBox(height: 8),
                    _buildModalRow('Monthly EMI:', _currencyFormat.format(emi)),
                    const SizedBox(height: 8),
                    _buildModalRow('Approved Interest Rate:', '$rate% p.a.'),
                    const SizedBox(height: 8),
                    _buildModalRow('Disbursal Bank:', '$bank ($maskedAcc)'),
                    const SizedBox(height: 8),
                    _buildModalRow('Acceptance Verification Fee:', '₹1.00', isHighlight: true, isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 2,
                    shadowColor: const Color(0xFF1E3A8A).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Proceed to Pay ₹1 via Razorpay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openExternalRazorpayLink(1.0, 'acceptance');
                  },
                ),
              ),
            ],
          ),
        ),
    );
  }

  // 2. Repayment BottomSheet Modal (EMI + Auto ₹100/day penalty)
  void _showRepayEmiModal(LoanApplication loan, Map<String, dynamic> data) {
    final emi = loan.monthlyEmi;
    final overdueDays = loan.daysOverdue;
    final penalty = loan.currentPenalty;
    final totalPayable = loan.totalCurrentPayable;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: overdueDays > 0
                          ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                          : [const Color(0xFF047857), const Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (overdueDays > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981)).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    overdueDays > 0 ? Icons.warning_rounded : Icons.payments_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overdueDays > 0 ? 'Overdue EMI Repayment' : 'EMI Repayment Checkout',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: overdueDays > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                        ),
                      ),
                      const Text('Secure payment directly via Razorpay UPI link', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildModalRow('Base Monthly EMI:', _currencyFormat.format(emi)),
                  if (overdueDays > 0) ...[
                    const SizedBox(height: 8),
                    _buildModalRow('Overdue Delay:', '$overdueDays Days', customColor: const Color(0xFFDC2626)),
                    const SizedBox(height: 8),
                    _buildModalRow('Late Penalty (₹100/day):', _currencyFormat.format(penalty), customColor: const Color(0xFFDC2626)),
                  ],
                  const Divider(height: 16),
                  _buildModalRow(
                    'Total Amount Payable:',
                    _currencyFormat.format(totalPayable),
                    isBold: true,
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Penalty Warning Notice below button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Note: Agar time se payment nahi kiya toh ₹100 per day penalty charge lagega.',
                      style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Primary Payment Action (Auto amount pre-fill)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: overdueDays > 0 ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 2,
                  shadowColor: (overdueDays > 0 ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A)).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  'Pay EMI (${_currencyFormat.format(totalPayable)}) via Razorpay',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openExternalRazorpayLink(totalPayable, 'emi');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String title, String val, {bool isBold = false, bool isHighlight = false, Color? customColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 6,
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: customColor ?? (isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Loan Status & Repayment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('applications').doc(widget.applicationId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Application not found', style: TextStyle(fontSize: 15)));
          }

          final loan = LoanApplication.fromFirestore(snapshot.data!);
          final data = snapshot.data!.data() as Map<String, dynamic>;

          if (loan.isBlocked) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.block_rounded, size: 54, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 18),
                    const Text('Account Suspended', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    const SizedBox(height: 8),
                    const Text('This account has been flagged and suspended by the credit administrator.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
            );
          }

          // 1. UNDER REVIEW
          if (loan.status == 'under_review') {
            final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, size: 48, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Application Under Credit Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text(
                    'Our Credit Admin is reviewing your KYC documents & eligibility. Once approved, you can accept the offer by paying ₹1 verification fee and receive instant disbursal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('APPLICATION DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8)),
                        const Divider(height: 16),
                        _buildStatusDetailRow('Requested Loan Amount:', _currencyFormat.format(loan.amount), isBold: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Selected Tenure:', loan.tenureDisplay),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Disbursal Bank Account:', '${loan.bankName} ($maskedAcc)'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // 2. REJECTED
          if (loan.status == 'rejected') {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.cancel_rounded, size: 54, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 18),
                  const Text('Application Declined', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  const SizedBox(height: 8),
                  Text(
                    loan.rejectionReason ?? 'Your application did not meet credit criteria at this time.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          // 3. APPROVED - USER REVIEWS OFFER, TICKS CONSENT & PAYS ₹1 ACCEPTANCE FEE
          if (loan.status == 'approved') {
            final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Loan Approved by Admin!',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Approved Loan Amount', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(_currencyFormat.format(loan.amount), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            '🎯 Admin Approved Rate: ${loan.interestRate.toStringAsFixed(1)}% p.a.',
                            style: const TextStyle(color: Color(0xFFFCD34D), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (loan.acceptanceRejectReason != null && loan.acceptanceRejectReason!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '⚠️ ₹1 Payment Rejected: ${loan.acceptanceRejectReason}\nPlease pay ₹1 on the Razorpay link and submit the correct UTR / Reference ID.',
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Offer Financial Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('APPROVED LOAN BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8)),
                        const Divider(height: 16),
                        _buildStatusDetailRow('Principal Loan Amount:', _currencyFormat.format(loan.amount), isBold: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Interest Rate (Admin Set):', '${loan.interestRate.toStringAsFixed(1)}% p.a.'),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Repayment Tenure:', loan.tenureDisplay),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow(
                          loan.tenureDays > 0 && loan.tenureMonths == 0 ? 'Single Bullet Due Amount:' : 'Monthly EMI Amount:',
                          _currencyFormat.format(loan.monthlyEmi),
                          isBold: true,
                          isHighlight: true,
                        ),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Total Repayment Amount:', _currencyFormat.format(loan.totalRepayment), isBold: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Disbursal Bank:', '${loan.bankName} ($maskedAcc)'),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Acceptance Verification Charge:', '₹1.00', isHighlight: true, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Consent Checkbox Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _userOfferConsentChecked ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _userOfferConsentChecked ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _userOfferConsentChecked,
                          activeColor: const Color(0xFF059669),
                          onChanged: (v) => setState(() => _userOfferConsentChecked = v ?? false),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _userOfferConsentChecked = !_userOfferConsentChecked),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'I accept approved loan of ${_currencyFormat.format(loan.amount)} at ${loan.interestRate.toStringAsFixed(1)}% interest. I agree to pay ₹1 acceptance fee to confirm disbursal into my bank account.',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.35),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay ₹1 Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _userOfferConsentChecked ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isProcessingPayment
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.payments_rounded, size: 20),
                      label: Text(
                        _userOfferConsentChecked ? 'Pay ₹1 & Accept Loan Offer' : 'Tick Consent Above to Proceed',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _userOfferConsentChecked && !_isProcessingPayment
                          ? () => _showAcceptanceModal(data)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }

          // 3.5. ACCEPTANCE SUBMITTED (₹1 Paid by User, Awaiting Admin Review)
          if (loan.status == 'acceptance_submitted') {
            final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;
            final utr = loan.acceptancePaymentId ?? loan.razorpayPaymentId ?? 'N/A';
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFFD97706).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.hourglass_top_rounded, size: 54, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(height: 16),
                  const Text('⚡ ₹1 Verification Under Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Your ₹1 verification payment (UTR: $utr) has been submitted. Our admin credit team is verifying the transaction in the bank statement. Once verified, loan disbursal of ${_currencyFormat.format(loan.netDisbursalAmount > 0 ? loan.netDisbursalAmount : loan.amount)} will be processed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildStatusDetailRow('Submitted UTR / Ref:', utr, isBold: true, isHighlight: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Net Disbursal Amount:', _currencyFormat.format(loan.netDisbursalAmount > 0 ? loan.netDisbursalAmount : loan.amount), isBold: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Target Bank:', '${loan.bankName} ($maskedAcc)'),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Verification Status:', '⏳ Admin Approval Pending', isHighlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Edit / Re-enter UTR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _showUtrSubmissionDialog(1.0, 'acceptance'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open Payment Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _openExternalRazorpayLink(1.0, 'acceptance'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          // 4. ACCEPTANCE DONE (₹1 Paid) - WAITING FOR ADMIN DISBURSAL
          if (loan.status == 'acceptance_done' || loan.status == 'autopay_done') {
            final maskedAcc = loan.accountNumber.length > 4 ? '****${loan.accountNumber.substring(loan.accountNumber.length - 4)}' : loan.accountNumber;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, size: 54, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 16),
                  const Text('⚡ Loan Accepted (₹1 Verified)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Your ₹1 verification is confirmed (Ref: ${loan.acceptancePaymentId ?? loan.razorpayPaymentId ?? 'Verified'}). Admin credit desk has been notified for bank disbursal of ${_currencyFormat.format(loan.netDisbursalAmount > 0 ? loan.netDisbursalAmount : loan.amount)}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildStatusDetailRow('Net Disbursal in Progress:', _currencyFormat.format(loan.netDisbursalAmount > 0 ? loan.netDisbursalAmount : loan.amount), isBold: true, isHighlight: true),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Target Bank:', '${loan.bankName} ($maskedAcc)'),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Verification Ref:', loan.acceptancePaymentId ?? loan.razorpayPaymentId ?? 'Verified'),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Status:', '⚡ In Disbursal Queue', isHighlight: true),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // 5. DISBURSED - ACTIVE REPAYMENT & AUTO ₹100/DAY PENALTY TRACKER (ZERO OVERFLOW)
          if (loan.status == 'disbursed') {
            final daysOverdue = loan.daysOverdue;
            final isOverdue = loan.isOverdue;
            final penalty = loan.currentPenalty;
            final totalPayable = loan.totalCurrentPayable;
            final dueDateStr = _dateFormat.format(loan.effectiveDueDate);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loan.pendingEmiPaymentId != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EMI Payment Verification in Progress',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Submitted: ${_currencyFormat.format(loan.pendingEmiAmount ?? loan.monthlyEmi)} (UTR: ${loan.pendingEmiPaymentId}). Admin team is verifying with bank records.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (loan.pendingEmiRejectReason != null && loan.pendingEmiRejectReason!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Previous EMI Payment Proof Rejected',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Reason: ${loan.pendingEmiRejectReason}. Please pay again and submit valid UTR.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Disbursed Card with ZERO horizontal overflow
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverdue
                            ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                            : [const Color(0xFF0F172A), const Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isOverdue ? '⚠️ EMI OVERDUE' : '🎉 Loan Active',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                isOverdue ? '$daysOverdue Days Late' : 'On Track',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(isOverdue ? 'Total Overdue Amount' : 'Current EMI Amount Due', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(totalPayable),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 12),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text('Due Date: $dueDateStr', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Overdue Penalty Alert Banner
                  if (isOverdue) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Late Penalty of ₹100/Day is Accumulating!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your repayment was due on $dueDateStr. System has added ₹${daysOverdue * 100} penalty ($daysOverdue days × ₹100). Please repay to avoid further charges.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Repayment Amount Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REPAYMENT BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8)),
                        const Divider(height: 16),
                        _buildStatusDetailRow('Principal Loan Disbursed:', _currencyFormat.format(loan.amount)),
                        const SizedBox(height: 6),
                        _buildStatusDetailRow('Base EMI Amount:', _currencyFormat.format(loan.monthlyEmi), isBold: true),
                        if (isOverdue) ...[
                          const SizedBox(height: 6),
                          _buildStatusDetailRow('Overdue Days:', '$daysOverdue Days Late', isBold: true, customColor: const Color(0xFFDC2626)),
                          const SizedBox(height: 6),
                          _buildStatusDetailRow('Daily Penalty (@ ₹100/day):', '+${_currencyFormat.format(penalty)}', isBold: true, customColor: const Color(0xFFDC2626)),
                        ],
                        const Divider(height: 14),
                        _buildStatusDetailRow('Total Payable Now:', _currencyFormat.format(totalPayable), isBold: true, isHighlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tap to Pay EMI Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isProcessingPayment
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.touch_app_rounded, size: 20),
                      label: Text(
                        'Tap to Pay EMI (${_currencyFormat.format(totalPayable)})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isProcessingPayment ? null : () => _showRepayEmiModal(loan, data),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Explicit Notice text below button required by user
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      '⚠️ Note: Agar time se payment nahi kiya toh per day ₹100 penalty charge lagega.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }

          // 6. REPAID / COMPLETED
          if (loan.status == 'repaid' || loan.status == 'completed') {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.task_alt_rounded, size: 54, color: Color(0xFF059669)),
                  ),
                  const SizedBox(height: 18),
                  const Text('🎉 Loan Closed & Fully Repaid!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  const SizedBox(height: 6),
                  Text(
                    'Thank you for timely repayments on Loan #${loan.id}. Your credit score has been positively updated.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return Center(child: Text('Current Status: ${loan.status}'));
        },
      ),
    );
  }

  Widget _buildStatusDetailRow(String title, String val, {bool isBold = false, bool isHighlight = false, Color? customColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 6,
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: customColor ?? (isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}
