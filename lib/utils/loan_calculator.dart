import 'dart:math';

class LoanCalculationResult {
  final double principal;
  final double annualRate;
  final int tenureDays;
  final int tenureMonths;
  final String tenureDisplay;
  final bool isShortTermDays;
  final double emi;
  final double totalRepayment;
  final double totalInterest;
  final double processingFee;
  final double netDisbursal;
  final String paymentFrequencyText;

  const LoanCalculationResult({
    required this.principal,
    required this.annualRate,
    required this.tenureDays,
    required this.tenureMonths,
    required this.tenureDisplay,
    required this.isShortTermDays,
    required this.emi,
    required this.totalRepayment,
    required this.totalInterest,
    required this.processingFee,
    required this.netDisbursal,
    required this.paymentFrequencyText,
  });
}

class LoanCalculator {
  static LoanCalculationResult calculate({
    required double principal,
    required double annualRate,
    int? tenureDays,
    int? tenureMonths,
    double processingFee = 0.0,
  }) {
    if (principal <= 0) {
      return LoanCalculationResult(
        principal: 0,
        annualRate: annualRate,
        tenureDays: 0,
        tenureMonths: 0,
        tenureDisplay: '0 Days',
        isShortTermDays: false,
        emi: 0,
        totalRepayment: 0,
        totalInterest: 0,
        processingFee: processingFee,
        netDisbursal: 0,
        paymentFrequencyText: 'Single Bullet Payment',
      );
    }

    final effectiveDays = tenureDays ?? 0;
    final effectiveMonths = tenureMonths ?? 0;
    final isDays = (effectiveDays > 0 && effectiveDays <= 30 && (effectiveMonths == 0 || effectiveDays == 7 || effectiveDays == 15));

    if (isDays) {
      // 7 days or 15 days short term loan
      // Flat % interest for short term period (e.g. 10% on ₹1,000 = ₹100 interest => ₹1,100 repayment)
      double totalInterest = (principal * (annualRate / 100.0)).roundToDouble();
      double totalRepayment = principal + totalInterest;
      double emi = totalRepayment; // 1-time single bullet repayment on due date
      String tenureDisplay = '$effectiveDays Days';
      String frequencyText = 'Single Bullet Repayment in $effectiveDays Days';

      return LoanCalculationResult(
        principal: principal,
        annualRate: annualRate,
        tenureDays: effectiveDays,
        tenureMonths: 0,
        tenureDisplay: tenureDisplay,
        isShortTermDays: true,
        emi: emi,
        totalRepayment: totalRepayment,
        totalInterest: totalInterest,
        processingFee: processingFee,
        netDisbursal: principal,
        paymentFrequencyText: frequencyText,
      );
    } else {
      // Months based loan (1 to 12 months / 1 Year)
      final months = effectiveMonths > 0 ? effectiveMonths : max(1, (effectiveDays / 30).round());
      String tenureDisplay = months == 12 ? '1 Year (12 Months)' : '$months ${months == 1 ? "Month" : "Months"}';

      if (months == 1) {
        double totalInterest = (principal * (annualRate / 100.0)).roundToDouble();
        double totalRepayment = principal + totalInterest;
        double emi = totalRepayment;

        return LoanCalculationResult(
          principal: principal,
          annualRate: annualRate,
          tenureDays: 30,
          tenureMonths: 1,
          tenureDisplay: tenureDisplay,
          isShortTermDays: false,
          emi: emi,
          totalRepayment: totalRepayment,
          totalInterest: totalInterest,
          processingFee: processingFee,
          netDisbursal: principal,
          paymentFrequencyText: 'Single 1-Month Repayment',
        );
      } else {
        // Annualized percentage across months: Total Interest = P * (annualRate / 100) * (months / 12)
        double totalInterest = (principal * (annualRate / 100.0) * (months / 12.0)).roundToDouble();
        double totalRepayment = principal + totalInterest;
        double emi = (totalRepayment / months).roundToDouble();

        return LoanCalculationResult(
          principal: principal,
          annualRate: annualRate,
          tenureDays: months * 30,
          tenureMonths: months,
          tenureDisplay: tenureDisplay,
          isShortTermDays: false,
          emi: emi,
          totalRepayment: totalRepayment,
          totalInterest: totalInterest,
          processingFee: processingFee,
          netDisbursal: principal,
          paymentFrequencyText: '₹${emi.toStringAsFixed(0)}/mo for $months Months',
        );
      }
    }
  }

  static double calculateEmi({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    int? tenureDays,
  }) {
    if (principal <= 0) return 0;
    if (tenureDays != null && (tenureDays == 7 || tenureDays == 15)) {
      double totalInterest = (principal * (annualRate / 100.0)).roundToDouble();
      return principal + totalInterest;
    }
    if (tenureMonths <= 0) return 0;
    if (tenureMonths == 1) {
      double totalInterest = (principal * (annualRate / 100.0)).roundToDouble();
      return principal + totalInterest;
    }
    double totalInterest = (principal * (annualRate / 100.0) * (tenureMonths / 12.0)).roundToDouble();
    double totalRepayment = principal + totalInterest;
    return (totalRepayment / tenureMonths).roundToDouble();
  }

  static double calculateTotalRepayment({
    required double emi,
    required int tenureMonths,
    int? tenureDays,
  }) {
    if (tenureDays != null && (tenureDays == 7 || tenureDays == 15)) {
      return emi;
    }
    return emi * max(1, tenureMonths);
  }

  static double calculateTotalInterest({
    required double principal,
    required double totalRepayment,
  }) => max(0.0, totalRepayment - principal);
}

