import '../../../core/value_objects/money.dart';

class ProjectCostSummary {
  const ProjectCostSummary({
    required this.materialCost,
    required this.laborCost,
    required this.machineryCost,
    required this.fuelCost,
    required this.repairCost,
    required this.otherExpenseCost,
    required this.agreementFinalValue,
    required this.totalReceivedAmount,
  });

  final Money materialCost;
  final Money laborCost;
  final Money machineryCost;
  final Money fuelCost;
  final Money repairCost;
  final Money otherExpenseCost;
  final Money agreementFinalValue;
  final Money totalReceivedAmount;

  Money get totalActualCost {
    return materialCost +
        laborCost +
        machineryCost +
        fuelCost +
        repairCost +
        otherExpenseCost;
  }

  Money get actualProfitByAgreement => agreementFinalValue - totalActualCost;
  Money get actualProfitByReceived => totalReceivedAmount - totalActualCost;
}
