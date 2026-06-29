import '../../../core/value_objects/money.dart';
import 'tender_application.dart';
import 'tender_status.dart';

class TenderBusinessService {
  const TenderBusinessService();

  Money calculateInlineApplicationCost(TenderDraft draft) {
    return Money.fromPaise(draft.inlineApplicationCostPaise);
  }

  Money calculateTotalApplicationCost({
    required TenderApplication tender,
    required Iterable<int> expenseAmountsPaise,
  }) {
    final expenses =
        expenseAmountsPaise.fold<int>(0, (sum, amount) => sum + amount);
    return Money.fromPaise(tender.inlineApplicationCostPaise + expenses);
  }

  void validateTenderDraft(TenderDraft draft) {
    if (draft.tenderTitle.trim().isEmpty) {
      throw ArgumentError.value(
          draft.tenderTitle, 'tenderTitle', 'Tender title is required.');
    }
    for (final amount in [
      draft.estimatedTenderValue,
      draft.quotedTenderPrice,
      draft.emdAmount,
      draft.tenderFee,
      draft.documentFee,
      draft.processingCost,
      draft.otherApplicationCost,
    ]) {
      if (amount.paise < 0) {
        throw ArgumentError.value(
            amount.paise, 'amount', 'Tender money values cannot be negative.');
      }
    }
  }

  void ensureCanConvert(TenderApplication tender) {
    if (tender.status != TenderStatus.selected) {
      throw StateError('Only selected tenders can be converted to projects.');
    }
  }
}
