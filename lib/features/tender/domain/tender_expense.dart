import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import 'tender_expense_type.dart';

@immutable
class TenderExpenseDraft {
  const TenderExpenseDraft({
    required this.tenderId,
    required this.expenseDate,
    required this.expenseType,
    required this.amount,
    this.description,
    this.paidTo,
    this.paymentMode,
    this.receiptPath,
    this.notes,
  });

  final String tenderId;
  final int expenseDate;
  final TenderExpenseType expenseType;
  final Money amount;
  final String? description;
  final String? paidTo;
  final String? paymentMode;
  final String? receiptPath;
  final String? notes;

  Map<String, Object?> toPayload() {
    return {
      'tenderId': tenderId,
      'expenseDate': expenseDate,
      'expenseType': expenseType.value,
      'amountPaise': amount.paise,
      'description': description,
      'paidTo': paidTo,
      'paymentMode': paymentMode,
      'receiptPath': receiptPath,
      'notes': notes,
    };
  }
}

@immutable
class TenderExpense {
  const TenderExpense({
    required this.id,
    required this.companyId,
    required this.tenderId,
    required this.expenseDate,
    required this.expenseType,
    required this.amount,
    this.description,
    this.paidTo,
    this.paymentMode,
    this.receiptPath,
    this.notes,
  });

  final String id;
  final String companyId;
  final String tenderId;
  final int expenseDate;
  final TenderExpenseType expenseType;
  final Money amount;
  final String? description;
  final String? paidTo;
  final String? paymentMode;
  final String? receiptPath;
  final String? notes;
}
