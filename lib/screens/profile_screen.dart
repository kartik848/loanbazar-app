import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/support_modal.dart';
import 'auth_screen.dart';
import 'apply_loan_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final fallbackName = user?.name ?? 'Loan Customer';
    final fallbackEmail = user?.email ?? '';
    final fallbackPhone = user?.phone ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('applications')
            .snapshots(),
        builder: (context, snapshot) {
          final allDocs = snapshot.data?.docs ?? [];
          Map<String, dynamic>? latestApp;
          if (allDocs.isNotEmpty) {
            final cleanPhone = fallbackPhone.replaceAll(RegExp(r'\D'), '');
            final u10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

            for (var d in allDocs) {
              final data = d.data() as Map<String, dynamic>;
              final p = (data['userPhone'] ?? data['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
              final l10 = p.length >= 10 ? p.substring(p.length - 10) : p;
              final e = (data['userEmail'] ?? '').toString().trim().toLowerCase();

              final pMatch = u10.isNotEmpty && l10 == u10;
              final eMatch = fallbackEmail.isNotEmpty && e == fallbackEmail.trim().toLowerCase();

              if (pMatch || eMatch) {
                latestApp = data;
                break;
              }
            }
          }

          final displayName = fallbackName.isNotEmpty ? fallbackName : (latestApp?['fullName'] ?? 'Loan Customer');
          final displayPhone = fallbackPhone.isNotEmpty ? fallbackPhone : (latestApp?['userPhone'] ?? latestApp?['phone'] ?? '');
          final displayEmail = fallbackEmail.isNotEmpty ? fallbackEmail : (latestApp?['userEmail'] ?? '');
          final selfieUrl = (latestApp?['selfieUrl'] as String?) ?? user?.photoUrl;

          final bool hasKyc = latestApp != null && (latestApp['panNumber'] != null || latestApp['panUrl'] != null || latestApp['selfieUrl'] != null);
          final bool isVerified = latestApp != null && (latestApp['status'] == 'approved' || latestApp['status'] == 'autopay_done' || latestApp['status'] == 'disbursed');
          final String kycStatusText = isVerified
              ? 'Verified ✓'
              : (hasKyc ? 'Under Review ⏳' : 'Not Submitted ✕');

          final bool hasBank = latestApp != null && latestApp['bankName'] != null;
          final bool isAutoPayActive = latestApp != null && (latestApp['status'] == 'autopay_done' || latestApp['status'] == 'disbursed');
          final String bankStatusText = isAutoPayActive
              ? 'AutoPay Active ⚡'
              : (hasBank ? 'Account Linked ✓' : 'Not Linked ✕');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Luxury Obsidian Titanium User Profile Card
              Container(
                padding: const EdgeInsets.all(22),
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
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFF0F172A),
                        backgroundImage: (selfieUrl != null && selfieUrl.isNotEmpty && selfieUrl.startsWith('http'))
                            ? NetworkImage(selfieUrl)
                            : null,
                        child: (selfieUrl == null || selfieUrl.isEmpty || !selfieUrl.startsWith('http'))
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 26, color: Color(0xFFF59E0B), fontWeight: FontWeight.w900),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (displayPhone.toString().isNotEmpty)
                            Text(
                              '📱 +91 $displayPhone',
                              style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          if (displayEmail.toString().isNotEmpty)
                            Text(
                              displayEmail,
                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section 1: Account & Financial Services
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'FINANCIAL & KYC SERVICES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
              ),

              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    // 1. KYC & Verification
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.security_rounded, color: Color(0xFF1E3A8A), size: 22),
                      ),
                      title: const Text('KYC & Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        'Selfie, PAN, Aadhaar & Residence • $kycStatusText',
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified ? const Color(0xFF059669) : (hasKyc ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                          fontWeight: isVerified ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      onTap: () => _showKycDetailsModal(context, latestApp),
                    ),
                    const Divider(height: 1, indent: 60),

                    // 2. Bank Accounts & AutoPay
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      title: const Text('Bank Accounts & AutoPay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        hasBank ? '${latestApp['bankName']} • $bankStatusText' : 'Disbursal A/C & e-Mandate • $bankStatusText',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAutoPayActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          fontWeight: isAutoPayActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      onTap: () => _showBankAutoPayModal(context, latestApp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Legal, Privacy & Compliance (Google Play & RBI)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'LEGAL, PRIVACY & SUPPORT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
              ),

              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    // 3. Privacy Policy & Legal Disclosures
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFD97706), size: 22),
                      ),
                      title: const Text('Privacy Policy & Legal Disclosures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Google Play & RBI Lending Terms • Zero Media Access', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      onTap: () => _showPrivacyPolicyModal(context),
                    ),
                    const Divider(height: 1, indent: 60),

                    // 4. Help & Support
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 22),
                      ),
                      title: const Text('24x7 Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Call & WhatsApp Helpline: 9016131681', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      onTap: () => SupportModal.show(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log Out of Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () {
                    AuthService().logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Loan Bazar App v2.5.0 • RBI Digital Lending Compliant',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 1. KYC & VERIFICATION MODAL
  // =========================================================================
  void _showKycDetailsModal(BuildContext context, Map<String, dynamic>? app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (app == null) {
          return _buildEmptyModal(
            context,
            icon: Icons.security_rounded,
            title: 'No KYC Submitted Yet',
            description: 'You haven\'t submitted your KYC documents yet. Apply for an instant credit limit to complete KYC verification.',
            actionText: 'Apply for Loan Now',
            onAction: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen()));
            },
          );
        }

        final fullName = app['fullName'] ?? 'N/A';
        final pan = app['panNumber'] ?? 'N/A';
        final aadhaar = app['aadhaarNumber'] ?? 'N/A';
        final empType = app['employmentType'] ?? 'Salaried';
        final income = (app['monthlyIncome'] as num?)?.toDouble() ?? 0.0;
        final selfieUrl = app['selfieUrl'] as String?;
        final houseUrl = (app['housePhotoUrl'] ?? app['homePhotoUrl']) as String?;
        final panUrl = app['panUrl'] as String?;
        final aadhaarUrl = app['aadhaarUrl'] as String?;
        final incomeUrl = app['incomeProofUrl'] ?? app['proofUrl'] as String?;
        final status = app['status'] ?? 'under_review';
        final isVerified = status == 'approved' || status == 'autopay_done' || status == 'disbursed';

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildModalHandle(),
              _buildModalHeader(
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF1E3A8A),
                title: 'KYC & Verification Dossier',
                subtitle: 'Verified Government ID & Financial Profile',
                onClose: () => Navigator.pop(ctx),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Verification Status Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVerified ? 'KYC Verified & Authenticated ✓' : 'KYC Verification in Progress',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isVerified ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isVerified
                                      ? 'Your identity and credit profile are authenticated as per RBI digital lending norms.'
                                      : 'Our credit underwriting team is reviewing your documents.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isVerified ? const Color(0xFF166534) : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // User Personal Details
                    const Text('IDENTITY & PERSONAL DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    _buildInfoCard([
                      _buildInfoRow('Full Legal Name', fullName),
                      _buildInfoRow('PAN Card Number', pan),
                      _buildInfoRow('Aadhaar Number', aadhaar),
                      _buildInfoRow('Employment Type', empType),
                      _buildInfoRow('Monthly Income', '₹${income.toInt().toString()} / month'),
                    ]),
                    const SizedBox(height: 20),

                    // Uploaded KYC Documents
                    const Text('SUBMITTED KYC DOCUMENTS & PHOTOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    _buildDocPreviewCard(context, 'Applicant Live Selfie', selfieUrl, Icons.face_rounded),
                    const SizedBox(height: 10),
                    _buildDocPreviewCard(context, 'House / Residence Photo', houseUrl, Icons.home_rounded),
                    const SizedBox(height: 10),
                    _buildDocPreviewCard(context, 'PAN Card', panUrl, Icons.badge_outlined),
                    const SizedBox(height: 10),
                    _buildDocPreviewCard(context, 'Aadhaar Card', aadhaarUrl, Icons.credit_card),
                    const SizedBox(height: 10),
                    _buildDocPreviewCard(context, 'Income Proof / Salary Slip', incomeUrl, Icons.receipt_long_outlined),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 2. BANK ACCOUNTS & AUTOPAY MODAL
  // =========================================================================
  void _showBankAutoPayModal(BuildContext context, Map<String, dynamic>? app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (app == null || app['bankName'] == null) {
          return _buildEmptyModal(
            context,
            icon: Icons.account_balance_rounded,
            title: 'No Bank Account Linked',
            description: 'Link your bank account and authorize UPI AutoPay for instant loan disbursal within 24 hours.',
            actionText: 'Apply & Link Bank Account',
            onAction: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLoanScreen()));
            },
          );
        }

        final bank = app['bankName'] ?? 'Bank Account';
        final acc = app['accountNumber'] ?? '—';
        final ifsc = app['ifscCode'] ?? '—';
        final holder = app['accountHolderName'] ?? app['fullName'] ?? '—';
        final emi = (app['monthlyEmi'] as num?)?.toDouble() ?? 0.0;
        final status = app['status'] ?? 'under_review';
        final autoPayDone = status == 'autopay_done' || status == 'disbursed';
        final mandateRef = app['razorpayPaymentId'] as String?;
        final amount = (app['amount'] as num?)?.toDouble() ?? 0.0;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildModalHandle(),
              _buildModalHeader(
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Bank Accounts & AutoPay Mandate',
                subtitle: 'Direct Disbursal Account & Recurring EMI Mandate',
                onClose: () => Navigator.pop(ctx),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 1. Primary Disbursal Bank Account Card
                    const Text('DISBURSAL BANK ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    bank,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Primary Disbursal', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Account Number', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            acc,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('IFSC Code', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(ifsc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Account Holder', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(holder, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. UPI AutoPay Recurring Mandate Details
                    const Text('RECURRING UPI AUTOPAY MANDATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: autoPayDone ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: autoPayDone ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    autoPayDone ? Icons.bolt_rounded : Icons.pending_actions_rounded,
                                    color: autoPayDone ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    autoPayDone ? 'AutoPay Active & Verified' : 'Mandate Setup Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: autoPayDone ? const Color(0xFF1E3A8A) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: autoPayDone ? const Color(0xFF2563EB).withOpacity(0.12) : const Color(0xFFD97706).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  autoPayDone ? 'Razorpay e-Mandate' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: autoPayDone ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildAutoPayDetailRow('Monthly Auto-Debit EMI', '₹${emi.toStringAsFixed(2)} / month', isHighlight: true),
                          _buildAutoPayDetailRow('Recurring Debit Date', '5th of Every Month'),
                          _buildAutoPayDetailRow('Debit Bank Account', '$bank (${acc.length > 4 ? '****${acc.substring(acc.length - 4)}' : acc})'),
                          _buildAutoPayDetailRow('Sanctioned Loan Reference', '₹${amount.toInt()} Loan'),
                          if (mandateRef != null && mandateRef.isNotEmpty)
                            _buildAutoPayDetailRow('Mandate Authorization ID', mandateRef),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Compliance Info Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AutoPay mandates are authorized securely via NPCI & RBI guidelines. EMI is debited automatically only until full loan clearance.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 3. PRIVACY POLICY & GOOGLE PLAY LEGAL DISCLOSURES MODAL
  // =========================================================================
  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildModalHandle(),
              _buildModalHeader(
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFF1E3A8A),
                title: 'Privacy Policy & Legal Terms',
                subtitle: 'Google Play Financial Services & RBI Lending Compliance',
                onClose: () => Navigator.pop(ctx),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Summary Badge Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 20),
                              SizedBox(width: 8),
                              Text('100% SECURE & RBI COMPLIANT', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Loan Bazar operates in full adherence with the RBI Guidelines on Digital Lending and Google Play Financial Services Policy.',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Zero Media / Contacts Access (Google Play Mandatory)
                    _buildLegalSection(
                      icon: Icons.no_photography_outlined,
                      title: '1. Zero Contact & Media Access Policy (Strict)',
                      content: 'In compliance with Google Play Personal Loans Policy and RBI Guidelines, Loan Bazar does NOT:\n'
                          '• Request, read, copy, or store your private phone contacts.\n'
                          '• Access your personal photo gallery, camera roll, videos, or files.\n'
                          '• Read or collect personal SMS or call logs.\n'
                          '• Track continuous real-time device location trails.',
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Data Collection & Encryption
                    _buildLegalSection(
                      icon: Icons.lock_outline,
                      title: '2. User Data Collection & 256-Bit SSL Security',
                      content: 'We only collect user-submitted data required for credit evaluation and legal compliance:\n'
                          '• Identity & KYC: Live face selfie, house/residence photo, PAN Card, Aadhaar Card, Full Name, and Date of Birth.\n'
                          '• Financial & Income: Salary slip/income proof and designated disbursal bank account details.\n'
                          '• All data transmitted to our secure cloud servers is encrypted using 256-bit bank-grade SSL technology.',
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Right to Erasure / Data Deletion
                    _buildLegalSection(
                      icon: Icons.delete_forever_outlined,
                      title: '3. User Data Rights & Data Deletion Policy',
                      content: 'Users maintain full rights over their personal data. To request permanent deletion of your profile, documents, and account data:\n'
                          '• Email your deletion request to: privacy@loanbazar.com\n'
                          '• Call/WhatsApp our 24x7 Data Protection desk at: +91 9016131681\n'
                          'Requests are verified and processed within 7 business days, in accordance with applicable statutory loan retention laws.',
                    ),
                    const SizedBox(height: 14),

                    // Section 4: Lending Service Provider & NBFC Partners
                    _buildLegalSection(
                      icon: Icons.account_balance_outlined,
                      title: '4. LSP Model & Regulated Lending Entities',
                      content: 'Loan Bazar acts as a Digital Lending Service Provider (LSP) partnering with RBI-registered Non-Banking Financial Companies (NBFCs) and Scheduled Commercial Banks. Loan underwriting, sanction letters, and disbursements are executed strictly by our regulated NBFC partners.',
                    ),
                    const SizedBox(height: 14),

                    // Section 5: Interest Rates, Tenures & Fee Disclosures
                    _buildLegalSection(
                      icon: Icons.percent_rounded,
                      title: '5. Transparent APR, Tenure & Fee Structure',
                      content: '• Repayment Tenure: 3 Months to 12 Months.\n'
                          '• Annual Percentage Rate (APR): 12.0% to 24.0% p.a. (Reducing Balance Method).\n'
                          '• Upfront Processing Fee: ₹200 (Disclosed transparently prior to loan acceptance).\n'
                          '• Foreclosure / Prepayment Penalty: ₹0 (Zero Penalty).',
                    ),
                    const SizedBox(height: 14),

                    // Section 6: Grievance Redressal & Nodal Officer
                    _buildLegalSection(
                      icon: Icons.contact_support_outlined,
                      title: '6. Grievance Redressal & Nodal Officer Details',
                      content: 'For complaints, disputes, or assistance:\n'
                          '• Nodal Grievance Officer: Mr. R. Sharma (Chief Compliance Officer)\n'
                          '• Email: grievance@loanbazar.com\n'
                          '• Helpline & WhatsApp: +91 9016131681 (24x7 Active)\n'
                          '• RBI Ombudsman: https://cms.rbi.org.in',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildModalHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildModalHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildDocPreviewCard(BuildContext context, String docTitle, String? url, IconData icon) {
    final hasDoc = url != null && url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDoc ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasDoc ? const Color(0xFF86EFAC) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: hasDoc ? const Color(0xFF059669) : const Color(0xFF64748B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(docTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                Text(hasDoc ? 'Document Uploaded & Verified ✓' : 'Not uploaded', style: TextStyle(fontSize: 11, color: hasDoc ? const Color(0xFF059669) : Colors.red)),
              ],
            ),
          ),
          if (hasDoc)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.visibility, size: 14),
              label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showImageDialog(context, docTitle, url),
            ),
        ],
      ),
    );
  }

  Widget _buildAutoPayDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection({required IconData icon, required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyModal(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModalHandle(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onAction,
              child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(child: Text('Image Preview Unavailable')),
                      )
                    : const Center(child: Text('Document verified in secure storage')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
