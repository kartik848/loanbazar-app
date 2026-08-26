import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/loan_calculator.dart';
import '../services/upload_service.dart';
import '../services/auth_service.dart';
import '../widgets/support_modal.dart';
import 'loan_status_screen.dart';
import 'my_loans_screen.dart';

class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  final _picker = ImagePicker();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  String _employmentType = 'salaried';
  final _incomeController = TextEditingController(text: '35000');
  final _bankNameController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _confirmAccountNoController = TextEditingController();
  final _ifscController = TextEditingController();
  final _holderNameController = TextEditingController();

  // Loan Financials (Range: ₹1,000 to ₹1,00,000, Tenure: 7 Days to 1 Year)
  double _amount = 10000;
  final double _interestRate = 14.0;
  int _selectedTenureDays = 7;
  int _selectedTenureMonths = 0;
  String _selectedTenureLabel = '7 Days';
  bool _uploading = false;
  String _uploadingDocType = '';
  bool _rbiConsentAgreed = false;

  final List<Map<String, dynamic>> _tenureOptions = const [
    {'label': '7 Days', 'days': 7, 'months': 0},
    {'label': '15 Days', 'days': 15, 'months': 0},
    {'label': '1 Month', 'days': 30, 'months': 1},
    {'label': '3 Months', 'days': 90, 'months': 3},
    {'label': '6 Months', 'days': 180, 'months': 6},
    {'label': '9 Months', 'days': 270, 'months': 9},
    {'label': '1 Year', 'days': 365, 'months': 12},
  ];

  // Documents
  String? _selfieUrl;
  String? _housePhotoUrl;
  String? _panUrl;
  String? _aadhaarUrl;
  String? _incomeProofUrl;
  String? _bankStatementUrl;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
      _holderNameController.text = user.name;
    }
  }

  void _showKfsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Modal Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF059669), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Key Fact Statement (KFS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('RBI & Google Play Digital Lending Disclosures', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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

              // Modal Body Content (Scrollable)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Financial Breakdown Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LOAN SUMMARY (KEY FACT STATEMENT)', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          _buildKfsRow('Requested Principal Loan:', _currencyFormat.format(_amount), isBold: true),
                          _buildKfsRow('Selected Repayment Tenure:', _selectedTenureLabel),
                          _buildKfsRow('Interest Rate & Schedule:', 'To be assigned by Credit Admin upon review'),
                          _buildKfsRow('Disbursal Account:', 'Direct Bank Transfer via IMPS/NEFT'),
                          _buildKfsRow('Prepayment / Foreclosure Penalty:', 'Nil (Zero Penalty)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: LSP & Regulated Entity
                    _buildDisclosureSection(
                      icon: Icons.account_balance,
                      title: '1. Lending Service Provider (LSP) & NBFC Partners',
                      content: 'Loan Bazar operates as a Digital Lending Service Provider (LSP) in compliant partnership with RBI Regulated Non-Banking Financial Companies (NBFCs) and Banking Entities. All loan approvals, underwriting policies, and disbursals adhere strictly to the RBI Digital Lending Guidelines.',
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Credit Bureau Pull
                    _buildDisclosureSection(
                      icon: Icons.analytics_outlined,
                      title: '2. Credit Bureau Assessment Authorization',
                      content: 'You grant explicit authorization to Loan Bazar and its regulated lending partners to fetch, access, and verify your credit bureau records from CIBIL, Experian, Equifax, and CRIF High Mark to determine creditworthiness and eligibility.',
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Privacy & Zero Media Storage
                    _buildDisclosureSection(
                      icon: Icons.privacy_tip_outlined,
                      title: '3. Data Privacy & Zero Contact/Media Storage Compliance',
                      content: 'In compliance with Google Play Financial Services Policy and RBI Guidelines, Loan Bazar does NOT request, access, copy, or store your private contacts, call logs, SMS logs, camera roll media, or real-time location trails. Uploaded KYC documents are encrypted using 256-bit bank-grade SSL and used solely for identity verification.',
                    ),
                    const SizedBox(height: 16),

                    // Section 4: AutoPay & Disbursal
                    _buildDisclosureSection(
                      icon: Icons.autorenew,
                      title: '4. Recurring UPI AutoPay Mandate & Disbursal Policy',
                      content: 'Upon loan approval, the applicant agrees to authorize a recurring UPI AutoPay mandate via Razorpay for automatic EMI debit on the 5th of every month starting from the subsequent calendar month. Net approved funds are credited directly to the verified bank account within 24 hours.',
                    ),
                    const SizedBox(height: 16),

                    // Section 5: Grievance Officer
                    _buildDisclosureSection(
                      icon: Icons.contact_support_outlined,
                      title: '5. Grievance Redressal & Nodal Officer Details',
                      content: 'For any disputes, compliance concerns, or assistance:\n• Nodal Officer: Mr. R. Sharma (Chief Compliance Officer)\n• Email: grievance@loanbazar.com\n• Helpline / WhatsApp: +91 9016131681 (24x7 Support)\n• Escalation: RBI Ombudsman Scheme (https://cms.rbi.org.in)',
                    ),
                  ],
                ),
              ),

              // Modal Footer Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() => _rbiConsentAgreed = true);
                      Navigator.pop(ctx);
                    },
                    child: const Text('I Have Read & Accept Key Fact Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKfsRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? const Color(0xFF34D399) : Colors.white,
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.w500,
              fontSize: isHighlight ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclosureSection({required IconData icon, required String title, required String content}) {
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
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45)),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(String docType, String docTitle) async {
    ImageSource source;
    CameraDevice preferredCamera = CameraDevice.rear;

    if (docType == 'selfie') {
      // 1. Direct Front Camera Capture Only (No Gallery Allowed)
      source = ImageSource.camera;
      preferredCamera = CameraDevice.front;
    } else if (docType == 'house') {
      // 2. Direct Rear Camera Capture Only (No Gallery Allowed)
      source = ImageSource.camera;
      preferredCamera = CameraDevice.rear;
    } else {
      // 3. For KYC IDs: Choose Camera or Gallery
      final chosen = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text('Upload $docTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                const Text('Choose camera to take a photo or pick from device gallery.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          side: const BorderSide(color: Color(0xFF1E3A8A)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('From Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
      if (chosen == null) return;
      source = chosen;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: preferredCamera,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _uploading = true;
        _uploadingDocType = docTitle;
      });

      String? url = await UploadService.uploadImage(File(picked.path));

      setState(() {
        _uploading = false;
        _uploadingDocType = '';
        if (docType == 'selfie') {
          _selfieUrl = url;
          if (url != null && url.isNotEmpty) {
            AuthService().updateProfile(photoUrl: url);
          }
        }
        if (docType == 'house') _housePhotoUrl = url;
        if (docType == 'pan') _panUrl = url;
        if (docType == 'aadhaar') _aadhaarUrl = url;
        if (docType == 'income') _incomeProofUrl = url;
        if (docType == 'statement') _bankStatementUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: url != null ? const Color(0xFF059669) : Colors.red,
            content: Row(
              children: [
                Icon(url != null ? Icons.check_circle : Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(url != null ? '$docTitle captured successfully!' : 'Capture/Upload failed. Please retry.'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadingDocType = '';
      });
      _showError('Camera error: $e');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final aadhaar = _aadhaarController.text.trim();
    final pan = _panController.text.trim().toUpperCase();
    final income = double.tryParse(_incomeController.text.trim()) ?? 0;

    final bankName = _bankNameController.text.trim();
    final accountNo = _accountNoController.text.trim();
    final confirmAccountNo = _confirmAccountNoController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final holderName = _holderNameController.text.trim();

    // 1. Personal & Identity Mandatory Checks
    if (name.isEmpty || name.length < 3) {
      _showError('Mandatory: Please enter Applicant Full Name (min 3 characters)');
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _showError('Mandatory: Please enter a valid 10-digit Mobile Number');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showError('Mandatory: Please enter a valid Email Address');
      return;
    }
    if (aadhaar.length != 12 || int.tryParse(aadhaar) == null) {
      _showError('Mandatory: Please enter a valid 12-digit Aadhaar Number');
      return;
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan)) {
      _showError('Mandatory: Please enter a valid 10-digit PAN Number (e.g. ABCDE1234F)');
      return;
    }
    if (income < 5000) {
      _showError('Mandatory: Please enter valid Monthly Income (min ₹5,000)');
      return;
    }

    // 2. Disbursal Bank Account Mandatory Checks
    if (bankName.isEmpty) {
      _showError('Mandatory: Please enter Disbursal Bank Name');
      return;
    }
    if (accountNo.isEmpty || accountNo.length < 8) {
      _showError('Mandatory: Please enter Bank Account Number (min 8 digits)');
      return;
    }
    if (confirmAccountNo.isEmpty) {
      _showError('Mandatory: Please enter Confirm Account Number');
      return;
    }
    if (accountNo != confirmAccountNo) {
      _showError('Bank Account Numbers do not match! Please re-check.');
      return;
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      _showError('Mandatory: Please enter a valid 11-character IFSC Code (e.g. SBIN0001234)');
      return;
    }
    if (holderName.isEmpty || holderName.length < 3) {
      _showError('Mandatory: Please enter Account Holder Name as per bank records');
      return;
    }

    // 3. Mandatory Documents (Selfie, House, PAN, Aadhaar, Income)
    if (_selfieUrl == null || _selfieUrl!.isEmpty) {
      _showError('Mandatory: Please capture your Live Face Selfie using camera');
      return;
    }
    if (_housePhotoUrl == null || _housePhotoUrl!.isEmpty) {
      _showError('Mandatory: Please capture your House / Residence Front Photo using camera');
      return;
    }
    if (_panUrl == null || _panUrl!.isEmpty) {
      _showError('Mandatory: Please upload PAN Card photo');
      return;
    }
    if (_aadhaarUrl == null || _aadhaarUrl!.isEmpty) {
      _showError('Mandatory: Please upload Aadhaar Card photo');
      return;
    }
    if (_incomeProofUrl == null || _incomeProofUrl!.isEmpty) {
      _showError('Mandatory: Please upload Salary Slip / Income Proof');
      return;
    }

    // 4. RBI & Digital Lending KFS Agreement
    if (!_rbiConsentAgreed) {
      _showError('Mandatory: Please check the box to agree to the RBI Digital Lending & KFS Terms');
      return;
    }

    setState(() => _uploading = true);

    try {
      final blockedCheck = await FirebaseFirestore.instance
          .collection('applications')
          .where('userPhone', isEqualTo: phone)
          .where('isBlocked', isEqualTo: true)
          .limit(1)
          .get();

      if (blockedCheck.docs.isNotEmpty) {
        setState(() => _uploading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Account Restricted'),
                ],
              ),
              content: const Text('Your profile is currently restricted by compliance. Contact support for assistance.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }

      final activeCheck = await FirebaseFirestore.instance
          .collection('applications')
          .where('userPhone', isEqualTo: phone)
          .where('status', whereIn: ['under_review', 'approved', 'autopay_done'])
          .limit(1)
          .get();

      if (activeCheck.docs.isNotEmpty) {
        setState(() => _uploading = false);
        if (mounted) {
          final existingId = activeCheck.docs.first.id;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already have an active loan application in progress.')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoanStatusScreen(applicationId: existingId)),
          );
        }
        return;
      }

      final calc = LoanCalculator.calculate(
        principal: _amount,
        annualRate: _interestRate,
        tenureDays: _selectedTenureDays,
        tenureMonths: _selectedTenureMonths,
        processingFee: _amount <= 2000 ? 0.0 : 200.0,
      );

      var doc = await FirebaseFirestore.instance.collection('applications').add({
        'fullName': name,
        'userPhone': phone,
        'userEmail': email,
        'aadhaarNumber': aadhaar,
        'panNumber': pan,
        'employmentType': _employmentType,
        'monthlyIncome': income,
        'bankName': bankName,
        'accountNumber': accountNo,
        'ifscCode': ifsc,
        'accountHolderName': holderName,
        'amount': _amount,
        'processingFee': calc.processingFee,
        'netDisbursalAmount': calc.netDisbursal,
        'interestRate': _interestRate,
        'tenureMonths': _selectedTenureMonths,
        'tenureDays': _selectedTenureDays,
        'tenureDisplay': _selectedTenureLabel,
        'monthlyEmi': calc.emi,
        'totalRepayment': calc.totalRepayment,
        'totalInterest': calc.totalInterest,
        'selfieUrl': _selfieUrl,
        'housePhotoUrl': _housePhotoUrl,
        'homePhotoUrl': _housePhotoUrl,
        'panUrl': _panUrl,
        'aadhaarUrl': _aadhaarUrl,
        'incomeProofUrl': _incomeProofUrl,
        'bankStatementUrl': _bankStatementUrl,
        'proofUrl': _incomeProofUrl,
        'status': 'under_review',
        'isBlocked': false,
        'userConsentApproved': false,
        'autoPayConsentAccepted': false,
        'rbiConsentAccepted': true,
        'rbiConsentVersion': 'KFS_RBI_v2.4_2026',
        'consentTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _uploading = false);
      AuthService().updateProfile(
        name: name,
        email: email,
        phone: phone,
        photoUrl: _selfieUrl,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoanStatusScreen(applicationId: doc.id)),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      _showError('Submission failed: $e');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = LoanCalculator.calculate(
      principal: _amount,
      annualRate: _interestRate,
      tenureDays: _selectedTenureDays,
      tenureMonths: _selectedTenureMonths,
      processingFee: _amount <= 2000 ? 0.0 : 200.0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Apply for Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF38BDF8)),
            tooltip: '24x7 Support',
            onPressed: () => SupportModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'My Loans',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLoansScreen())),
          ),
        ],
      ),
      body: _uploading && _uploadingDocType.isNotEmpty
          ? Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF1E3A8A), strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text('Uploading $_uploadingDocType...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Encrypting and securing your KYC data', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Interactive Loan Calculator Hero Card
                  _buildLoanCalculatorCard(calc),
                  const SizedBox(height: 20),

                  // 2. Personal & Identity Details Card
                  _buildPersonalDetailsCard(),
                  const SizedBox(height: 20),

                  // 3. Disbursal Bank Account Card
                  _buildBankDetailsCard(),
                  const SizedBox(height: 20),

                  // 4. KYC & Financial Documents Center
                  _buildDocumentsUploadCard(),
                  const SizedBox(height: 20),

                  // 5. RBI Digital Lending Compliance & KFS Agreement
                  _buildRbiComplianceCard(),
                  const SizedBox(height: 24),

                  // 6. Final Submit Button
                  _buildSubmitSection(calc.emi),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // 1. Loan Calculator Card
  Widget _buildLoanCalculatorCard(LoanCalculationResult calc) {
    return Container(
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Instant Loan Calculator',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: const Text('₹1,000 to ₹1 Lakh ✓', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loan Amount Display
          const Text('Required Loan Amount (₹1,000 - ₹1,00,000)', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(_amount),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),

          // Amount Slider (1k to 100k)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFF59E0B),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFFF59E0B),
              overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
              trackHeight: 5,
            ),
            child: Slider(
              value: _amount.clamp(1000.0, 100000.0),
              min: 1000,
              max: 100000,
              divisions: 99,
              onChanged: (v) {
                setState(() {
                  _amount = v;
                  if (_amount <= 2000 && _selectedTenureMonths > 0) {
                    _selectedTenureDays = 7;
                    _selectedTenureMonths = 0;
                    _selectedTenureLabel = '7 Days';
                  }
                });
              },
            ),
          ),

          // Quick Amount Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [1000, 5000, 10000, 25000, 50000, 100000].map((amt) {
                final isSelected = _amount == amt.toDouble();
                String label;
                if (amt >= 100000) {
                  label = '₹1 Lakh';
                } else if (amt >= 1000) {
                  label = '₹${amt ~/ 1000}k';
                } else {
                  label = '₹$amt';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _amount = amt.toDouble();
                        if (amt == 1000) {
                          _selectedTenureDays = 7;
                          _selectedTenureMonths = 0;
                          _selectedTenureLabel = '7 Days';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Repayment Tenure (7 Days to 1 Year)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Repayment Tenure:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(_selectedTenureLabel, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tenureOptions.map((opt) {
                final label = opt['label'] as String;
                final days = opt['days'] as int;
                final months = opt['months'] as int;
                final isSelected = _selectedTenureLabel == label;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedTenureLabel = label;
                      _selectedTenureDays = days;
                      _selectedTenureMonths = months;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Selected Loan & Tenure Summary Box (Apply Amount only)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Applied Loan Amount:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(_currencyFormat.format(_amount), style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 22)),
                  ],
                ),
                const Divider(color: Colors.white12, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Selected Repayment Tenure:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(_selectedTenureLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Exact Interest Notice from Admin
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: Color(0xFF38BDF8), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exact interest rate (%) & repayment schedule will be reviewed and assigned by Admin Credit Team upon document verification. You will review and accept the final offer before disbursal.',
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 12, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Personal Details Card
  Widget _buildPersonalDetailsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.person_rounded, 'Personal & KYC Details', 'Enter your details exactly as per PAN & Aadhaar'),
            const SizedBox(height: 18),

            _buildInputField(
              controller: _nameController,
              label: 'Full Name (as per PAN)',
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _phoneController,
              label: 'Mobile Number',
              icon: Icons.phone_android,
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _aadhaarController,
              label: 'Aadhaar Number (12 Digits)',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _panController,
              label: 'PAN Card Number (10 Chars)',
              icon: Icons.assignment_ind_outlined,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
            ),
            const SizedBox(height: 16),

            const Text('Employment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildEmploymentOption('salaried', '💼 Salaried'),
                const SizedBox(width: 10),
                _buildEmploymentOption('business', '🏢 Self-Employed'),
              ],
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _incomeController,
              label: 'Monthly Net Take-Home Income',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentOption(String value, String label) {
    final isSelected = _employmentType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _employmentType = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A).withOpacity(0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 3. Bank Details Card
  Widget _buildBankDetailsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.account_balance_rounded, 'Disbursal Bank Account', 'Loan amount will be credited directly to this account'),
            const SizedBox(height: 18),

            _buildInputField(
              controller: _bankNameController,
              label: 'Bank Name (e.g. HDFC Bank, SBI)',
              icon: Icons.account_balance,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _accountNoController,
              label: 'Account Number',
              icon: Icons.tag,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _confirmAccountNoController,
              label: 'Confirm Account Number',
              icon: Icons.verified_user_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _ifscController,
              label: 'IFSC Code (11 Characters)',
              icon: Icons.qr_code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
            ),
            const SizedBox(height: 14),

            _buildInputField(
              controller: _holderNameController,
              label: 'Account Holder Name (as per Bank)',
              icon: Icons.person_pin,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }

  // 4. KYC Documents Upload Center
  Widget _buildDocumentsUploadCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.cloud_upload_rounded, 'Mandatory KYC & Verification Documents', 'All documents below are strictly required to process your loan'),
            const SizedBox(height: 18),

            _buildDocTile('selfie', 'Live Face Selfie', _selfieUrl, Icons.camera_front_rounded, isCameraOnly: true),
            const SizedBox(height: 12),
            _buildDocTile('house', 'House / Residence Front Photo', _housePhotoUrl, Icons.home_work_rounded, isCameraOnly: true),
            const SizedBox(height: 12),
            _buildDocTile('pan', 'PAN Card (Front)', _panUrl, Icons.badge_outlined),
            const SizedBox(height: 12),
            _buildDocTile('aadhaar', 'Aadhaar Card (Front / Back)', _aadhaarUrl, Icons.credit_card),
            const SizedBox(height: 12),
            _buildDocTile('income', 'Income Proof / Salary Slip', _incomeProofUrl, Icons.receipt_long_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildDocTile(String docKey, String title, String? url, IconData icon, {bool isCameraOnly = false}) {
    final isUploaded = url != null && url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUploaded ? const Color(0xFF86EFAC) : (isCameraOnly ? const Color(0xFFFDBA74) : const Color(0xFFE2E8F0)),
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUploaded
                  ? const Color(0xFF10B981).withOpacity(0.15)
                  : (isCameraOnly ? const Color(0xFFEA580C).withOpacity(0.12) : const Color(0xFF1E3A8A).withOpacity(0.1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle : icon,
              color: isUploaded
                  ? const Color(0xFF10B981)
                  : (isCameraOnly ? const Color(0xFFEA580C) : const Color(0xFF1E3A8A)),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ),
                    if (isCameraOnly && !isUploaded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: const Text(
                          '📷 Camera',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isUploaded
                      ? '✓ Live Encrypted & Verified'
                      : (isCameraOnly ? 'Live Camera Capture • Mandatory *' : 'Mandatory Document *'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isUploaded
                        ? const Color(0xFF059669)
                        : (isCameraOnly ? const Color(0xFFC2410C) : const Color(0xFF64748B)),
                    fontWeight: isUploaded || isCameraOnly ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(60, 36),
              backgroundColor: isUploaded
                  ? const Color(0xFFF0FDF4)
                  : (isCameraOnly ? const Color(0xFFEA580C) : const Color(0xFF1E3A8A)),
              foregroundColor: isUploaded ? const Color(0xFF059669) : Colors.white,
              elevation: 0,
              side: isUploaded ? const BorderSide(color: Color(0xFF059669)) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              isCameraOnly ? (isUploaded ? Icons.refresh : Icons.camera_alt_rounded) : (isUploaded ? Icons.edit : Icons.cloud_upload_outlined),
              size: 15,
            ),
            label: Text(
              isCameraOnly ? (isUploaded ? 'Retake' : 'Capture') : (isUploaded ? 'Change' : 'Upload'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            onPressed: () => _pickAndUpload(docKey, title),
          ),
        ],
      ),
    );
  }

  // 5. RBI Digital Lending Compliance & KFS Agreement Card
  Widget _buildRbiComplianceCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RBI Digital Lending Compliance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showKfsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 13, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text('View KFS', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'By applying, you agree to the Key Fact Statement (KFS), APR disclosures (12%-24% p.a.), zero contact/media access terms, and authorize CIBIL credit pull and recurring UPI AutoPay mandate.',
            style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showKfsModal,
            child: const Text(
              '📄 View Full RBI & Lending Terms (KFS) ➔',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669), decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _rbiConsentAgreed = !_rbiConsentAgreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _rbiConsentAgreed,
                  activeColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) => setState(() => _rbiConsentAgreed = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'I have read, understood, and accept the Key Fact Statement (KFS), Credit Bureau Check, and UPI AutoPay terms.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Submit Button & Live EMI Bar
  Widget _buildSubmitSection(double emi) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF0F172A).withOpacity(0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Submit Loan Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            '🔒 256-Bit Bank Grade SSL Encryption • No Hidden Fees',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? prefixText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }
}
