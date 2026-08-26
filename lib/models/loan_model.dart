import 'package:cloud_firestore/cloud_firestore.dart';

class LoanApplication {
  final String id;
  final String fullName;
  final String userPhone;
  final String userEmail;
  final String aadhaarNumber;
  final String panNumber;
  final String employmentType;
  final double monthlyIncome;
  
  // Bank Details for Disbursal
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String accountHolderName;

  // Loan Financials
  final double amount;
  final double interestRate;
  final int tenureMonths;
  final int tenureDays;
  final String tenureDisplay;
  final double monthlyEmi;
  final double totalRepayment;
  final double processingFee;
  final double netDisbursalAmount;

  // Document URLs
  final String? selfieUrl;
  final String? housePhotoUrl;
  final String? panUrl;
  final String? aadhaarUrl;
  final String? incomeProofUrl;
  final String? bankStatementUrl;

  // Status & Governance
  // 'under_review' | 'approved' | 'acceptance_done' | 'autopay_done' | 'disbursed' | 'repaid' | 'rejected'
  final String status;
  final bool isBlocked;
  final bool rbiConsentAccepted;
  final bool userConsentApproved; // User checked consent for admin's calculated offer
  final bool autoPayConsentAccepted;
  final bool acceptanceFeePaid;
  final String? acceptancePaymentId;
  final DateTime? acceptanceSubmittedAt;
  final DateTime? acceptancePaidAt;
  final String? acceptanceRejectReason;
  final String? pendingEmiPaymentId;
  final double? pendingEmiAmount;
  final DateTime? pendingEmiSubmittedAt;
  final String? pendingEmiRejectReason;
  final String? razorpayPaymentId;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? disbursedBy;
  final DateTime? disbursedAt;
  final DateTime? dueDate;
  final DateTime? nextEmiDueDate;
  final int emisPaid;
  final int totalEmis;
  final double penaltyPerDay;
  final DateTime createdAt;

  LoanApplication({
    required this.id,
    required this.fullName,
    required this.userPhone,
    required this.userEmail,
    required this.aadhaarNumber,
    required this.panNumber,
    required this.employmentType,
    required this.monthlyIncome,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountHolderName,
    required this.amount,
    required this.interestRate,
    required this.tenureMonths,
    this.tenureDays = 0,
    this.tenureDisplay = '',
    required this.monthlyEmi,
    required this.totalRepayment,
    this.processingFee = 0.0,
    this.netDisbursalAmount = 0.0,
    this.selfieUrl,
    this.housePhotoUrl,
    this.panUrl,
    this.aadhaarUrl,
    this.incomeProofUrl,
    this.bankStatementUrl,
    required this.status,
    this.isBlocked = false,
    this.rbiConsentAccepted = false,
    this.userConsentApproved = false,
    this.autoPayConsentAccepted = false,
    this.acceptanceFeePaid = false,
    this.acceptancePaymentId,
    this.acceptanceSubmittedAt,
    this.acceptancePaidAt,
    this.acceptanceRejectReason,
    this.pendingEmiPaymentId,
    this.pendingEmiAmount,
    this.pendingEmiSubmittedAt,
    this.pendingEmiRejectReason,
    this.razorpayPaymentId,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    this.disbursedBy,
    this.disbursedAt,
    this.dueDate,
    this.nextEmiDueDate,
    this.emisPaid = 0,
    this.totalEmis = 1,
    this.penaltyPerDay = 100.0,
    required this.createdAt,
  });

  // Calculate dynamic effective due date
  DateTime get effectiveDueDate {
    if (nextEmiDueDate != null) return nextEmiDueDate!;
    if (dueDate != null) return dueDate!;
    final baseDate = disbursedAt ?? createdAt;
    if (tenureDays > 0) {
      return baseDate.add(Duration(days: tenureDays));
    }
    final months = tenureMonths > 0 ? tenureMonths : 1;
    return baseDate.add(Duration(days: months * 30));
  }

  // Calculate overdue calendar days
  int get daysOverdue {
    if (status != 'disbursed') return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = effectiveDueDate;
    final dueCalendar = DateTime(due.year, due.month, due.day);
    final diff = today.difference(dueCalendar).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get isOverdue => daysOverdue > 0 && status == 'disbursed';

  // Dynamic live penalty amount (@ ₹100 per overdue day)
  double get currentPenalty => (daysOverdue * penaltyPerDay).toDouble();

  // Total payable for current EMI cycle (EMI + Penalty)
  double get totalCurrentPayable => monthlyEmi + currentPenalty;

  bool get isAcceptanceDone =>
      status == 'acceptance_done' ||
      status == 'autopay_done' ||
      acceptanceFeePaid;

  factory LoanApplication.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final tMonths = (data['tenureMonths'] as num?)?.toInt() ?? 6;
    final tDays = (data['tenureDays'] as num?)?.toInt() ?? (tMonths <= 0 ? 7 : tMonths * 30);
    final pFee = (data['processingFee'] as num?)?.toDouble() ?? 200.0;
    
    String calcDisplay = data['tenureDisplay'] ?? '';
    if (calcDisplay.isEmpty) {
      if (tDays == 7 || tDays == 15) {
        calcDisplay = '$tDays Days';
      } else if (tMonths == 12) {
        calcDisplay = '1 Year (12 Months)';
      } else {
        calcDisplay = '$tMonths Months';
      }
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return LoanApplication(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      userEmail: data['userEmail'] ?? '',
      aadhaarNumber: data['aadhaarNumber'] ?? '',
      panNumber: data['panNumber'] ?? '',
      employmentType: data['employmentType'] ?? 'salaried',
      monthlyIncome: (data['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      ifscCode: data['ifscCode'] ?? '',
      accountHolderName: data['accountHolderName'] ?? '',
      amount: amt,
      interestRate: (data['interestRate'] as num?)?.toDouble() ?? 14.0,
      tenureMonths: tMonths,
      tenureDays: tDays,
      tenureDisplay: calcDisplay,
      monthlyEmi: (data['monthlyEmi'] as num?)?.toDouble() ?? 0.0,
      totalRepayment: (data['totalRepayment'] as num?)?.toDouble() ?? 0.0,
      processingFee: pFee,
      netDisbursalAmount: (data['netDisbursalAmount'] as num?)?.toDouble() ?? (amt > pFee ? amt - pFee : amt),
      selfieUrl: data['selfieUrl'] ?? data['photoUrl'],
      housePhotoUrl: data['housePhotoUrl'] ?? data['homePhotoUrl'],
      panUrl: data['panUrl'],
      aadhaarUrl: data['aadhaarUrl'],
      incomeProofUrl: data['incomeProofUrl'] ?? data['proofUrl'],
      bankStatementUrl: data['bankStatementUrl'],
      status: data['status'] ?? 'under_review',
      isBlocked: data['isBlocked'] ?? false,
      rbiConsentAccepted: data['rbiConsentAccepted'] ?? false,
      userConsentApproved: data['userConsentApproved'] ?? false,
      autoPayConsentAccepted: data['autoPayConsentAccepted'] ?? false,
      acceptanceFeePaid: data['acceptanceFeePaid'] ?? (data['status'] == 'autopay_done' || data['status'] == 'acceptance_done'),
      acceptancePaymentId: data['acceptancePaymentId'] ?? data['razorpayPaymentId'],
      acceptanceSubmittedAt: parseDate(data['acceptanceSubmittedAt']),
      acceptancePaidAt: parseDate(data['acceptancePaidAt'] ?? data['autoPayEnabledAt']),
      acceptanceRejectReason: data['acceptanceRejectReason'],
      pendingEmiPaymentId: data['pendingEmiPaymentId'],
      pendingEmiAmount: (data['pendingEmiAmount'] as num?)?.toDouble(),
      pendingEmiSubmittedAt: parseDate(data['pendingEmiSubmittedAt']),
      pendingEmiRejectReason: data['pendingEmiRejectReason'],
      razorpayPaymentId: data['razorpayPaymentId'],
      rejectionReason: data['rejectionReason'],
      approvedBy: data['approvedBy'],
      approvedAt: parseDate(data['approvedAt']),
      disbursedBy: data['disbursedBy'],
      disbursedAt: parseDate(data['disbursedAt']),
      dueDate: parseDate(data['dueDate']),
      nextEmiDueDate: parseDate(data['nextEmiDueDate']),
      emisPaid: (data['emisPaid'] as num?)?.toInt() ?? 0,
      totalEmis: (data['totalEmis'] as num?)?.toInt() ?? (tMonths > 0 ? tMonths : 1),
      penaltyPerDay: (data['penaltyPerDay'] as num?)?.toDouble() ?? 100.0,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber,
      'employmentType': employmentType,
      'monthlyIncome': monthlyIncome,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'accountHolderName': accountHolderName,
      'amount': amount,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'tenureDays': tenureDays,
      'tenureDisplay': tenureDisplay,
      'monthlyEmi': monthlyEmi,
      'totalRepayment': totalRepayment,
      'processingFee': processingFee,
      'netDisbursalAmount': netDisbursalAmount,
      'selfieUrl': selfieUrl,
      'housePhotoUrl': housePhotoUrl,
      'panUrl': panUrl,
      'aadhaarUrl': aadhaarUrl,
      'incomeProofUrl': incomeProofUrl,
      'bankStatementUrl': bankStatementUrl,
      'status': status,
      'isBlocked': isBlocked,
      'rbiConsentAccepted': rbiConsentAccepted,
      'userConsentApproved': userConsentApproved,
      'autoPayConsentAccepted': autoPayConsentAccepted,
      'acceptanceFeePaid': acceptanceFeePaid,
      'acceptancePaymentId': acceptancePaymentId,
      'acceptanceSubmittedAt': acceptanceSubmittedAt != null ? Timestamp.fromDate(acceptanceSubmittedAt!) : null,
      'acceptancePaidAt': acceptancePaidAt != null ? Timestamp.fromDate(acceptancePaidAt!) : null,
      'acceptanceRejectReason': acceptanceRejectReason,
      'pendingEmiPaymentId': pendingEmiPaymentId,
      'pendingEmiAmount': pendingEmiAmount,
      'pendingEmiSubmittedAt': pendingEmiSubmittedAt != null ? Timestamp.fromDate(pendingEmiSubmittedAt!) : null,
      'pendingEmiRejectReason': pendingEmiRejectReason,
      'razorpayPaymentId': razorpayPaymentId,
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'disbursedBy': disbursedBy,
      'disbursedAt': disbursedAt != null ? Timestamp.fromDate(disbursedAt!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'nextEmiDueDate': nextEmiDueDate != null ? Timestamp.fromDate(nextEmiDueDate!) : null,
      'emisPaid': emisPaid,
      'totalEmis': totalEmis,
      'penaltyPerDay': penaltyPerDay,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

