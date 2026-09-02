import '../../../models/application_status.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';
import 'company_format.dart';
import 'drive_ordering.dart';

const int widgetSlotCount = 2;

class WidgetDrive {
  const WidgetDrive({required this.name, required this.line});

  final String name;
  final String line;
}

class WidgetFeed {
  const WidgetFeed({required this.headline, required this.drives});

  final String headline;
  final List<WidgetDrive> drives;

  bool get isEmpty => drives.isEmpty;
}

List<Company> _byDeadline(List<Company> companies) {
  return orderDrives(
    companies: companies,
    statusesByCompanyId: const {},
  ).toList(growable: false);
}

WidgetFeed buildWidgetFeed({
  required List<Company> companies,
  required Map<String, StudentCompanyStatus> statusesByCompanyId,
  DateTime? now,
}) {
  final shortlisted = <Company>[];
  final open = <Company>[];

  for (final company in companies) {
    final status = statusesByCompanyId[company.id];
    final application = DriveApplication(
      company: company,
      status: status,
      now: now,
    );

    if (application.isInProgress ||
        application.overallStatus == OverallStatus.selected) {
      shortlisted.add(company);
      continue;
    }

    if (company.status == CompanyStatus.registrationOpen &&
        status?.optedIn != true) {
      open.add(company);
    }
  }

  if (shortlisted.isNotEmpty) {
    return WidgetFeed(
      headline: 'You are through',
      drives: [
        for (final company in _byDeadline(shortlisted).take(widgetSlotCount))
          WidgetDrive(
            name: company.name,
            line: companyStage(company, now: now),
          ),
      ],
    );
  }

  return WidgetFeed(
    headline: 'Open now',
    drives: [
      for (final company in _byDeadline(open).take(widgetSlotCount))
        WidgetDrive(
          name: company.name,
          line: CompanyFormat.deadlineLabel(company.registrationDeadline),
        ),
    ],
  );
}
