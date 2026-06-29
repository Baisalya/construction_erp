import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import 'tender_status.dart';

@immutable
class TenderListItem {
  const TenderListItem({
    required this.id,
    required this.title,
    required this.status,
    required this.quotedPrice,
    required this.estimatedValue,
    required this.inlineApplicationCost,
    required this.extraExpenseTotal,
    this.tenderNumber,
    this.bidderProfileName,
    this.clientName,
    this.location,
  });

  final String id;
  final String title;
  final TenderStatus status;
  final Money quotedPrice;
  final Money estimatedValue;
  final Money inlineApplicationCost;
  final Money extraExpenseTotal;
  final String? tenderNumber;
  final String? bidderProfileName;
  final String? clientName;
  final String? location;

  Money get totalApplicationCost => inlineApplicationCost + extraExpenseTotal;
}

@immutable
class TenderDashboardStats {
  const TenderDashboardStats({
    required this.totalTenders,
    required this.activeTenders,
    required this.selectedTenders,
    required this.rejectedTenders,
    required this.totalQuotedValue,
    required this.totalApplicationCost,
  });

  final int totalTenders;
  final int activeTenders;
  final int selectedTenders;
  final int rejectedTenders;
  final Money totalQuotedValue;
  final Money totalApplicationCost;

  factory TenderDashboardStats.empty() {
    return const TenderDashboardStats(
      totalTenders: 0,
      activeTenders: 0,
      selectedTenders: 0,
      rejectedTenders: 0,
      totalQuotedValue: Money.zero,
      totalApplicationCost: Money.zero,
    );
  }
}
