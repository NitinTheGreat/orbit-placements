import '../../../models/company.dart';

String? applicationChannel(List<CompanyRequirement> requirements) {
  final types = requirements.map((requirement) => requirement.type).toSet();
  if (types.isEmpty) {
    return null;
  }
  if (types.length > 1) {
    return 'Multiple steps';
  }
  return switch (types.single) {
    RequirementType.neopat => 'NeoPAT',
    RequirementType.googleForm => 'Google Form',
    RequirementType.companySite => 'Company site',
    RequirementType.other => null,
  };
}
