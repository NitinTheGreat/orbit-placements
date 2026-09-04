import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/application_channel.dart';
import 'package:orbit/models/company.dart';

CompanyRequirement step(RequirementType type, [String id = 'a']) {
  return CompanyRequirement(id: id, type: type, label: 'Step');
}

void main() {
  test('a single NeoPAT step reads as NeoPAT', () {
    expect(applicationChannel([step(RequirementType.neopat)]), 'NeoPAT');
  });

  test('a single form step reads as Google Form', () {
    expect(applicationChannel([step(RequirementType.googleForm)]), 'Google Form');
  });

  test('a single company site step reads as Company site', () {
    expect(
      applicationChannel([step(RequirementType.companySite)]),
      'Company site',
    );
  });

  test('two of the same type is still that one channel', () {
    expect(
      applicationChannel([
        step(RequirementType.neopat, 'a'),
        step(RequirementType.neopat, 'b'),
      ]),
      'NeoPAT',
    );
  });

  test('more than one type reads as multiple steps', () {
    expect(
      applicationChannel([
        step(RequirementType.neopat, 'a'),
        step(RequirementType.googleForm, 'b'),
      ]),
      'Multiple steps',
    );
  });

  test('an unclassified step alone claims no channel', () {
    expect(applicationChannel([step(RequirementType.other)]), isNull);
  });

  test('an unclassified step alongside a known one still counts as multiple', () {
    expect(
      applicationChannel([
        step(RequirementType.other, 'a'),
        step(RequirementType.neopat, 'b'),
      ]),
      'Multiple steps',
    );
  });

  test('no requirements means no tag', () {
    expect(applicationChannel(const []), isNull);
  });
}
