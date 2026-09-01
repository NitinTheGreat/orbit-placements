import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/company.dart';
import '../models/student.dart';
import '../models/student_company_status.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _students =>
      _db.collection(FirestoreCollections.students);

  CollectionReference<Map<String, dynamic>> get _companies =>
      _db.collection(FirestoreCollections.companies);

  CollectionReference<Map<String, dynamic>> get _statuses =>
      _db.collection(FirestoreCollections.studentCompanyStatus);

  Future<bool> studentExists(String uid) async {
    final doc = await _students.doc(uid).get();
    return doc.exists;
  }

  Future<Student?> fetchStudent(String uid) async {
    final doc = await _students.doc(uid).get();
    return doc.exists ? Student.fromFirestore(doc) : null;
  }

  Future<void> createStudent(Student student) {
    return _students.doc(student.uid).set(student.toFirestore());
  }

  Stream<List<Company>> watchCompanies() {
    return _companies
        .orderBy('registrationDeadline')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Company.fromFirestore).toList(growable: false),
        );
  }

  Stream<Company?> watchCompany(String companyId) {
    return _companies
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? Company.fromFirestore(doc) : null);
  }

  Future<String> addCompany(Company company) async {
    final doc = await _companies.add(company.toFirestore());
    return doc.id;
  }

  Stream<StudentCompanyStatus?> watchStatus({
    required String studentId,
    required String companyId,
  }) {
    final id = StudentCompanyStatus.docIdFor(
      studentId: studentId,
      companyId: companyId,
    );
    return _statuses
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? StudentCompanyStatus.fromFirestore(doc) : null);
  }

  Stream<List<StudentCompanyStatus>> watchStatusesForStudent(String studentId) {
    return _statuses
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(StudentCompanyStatus.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> upsertStatus(StudentCompanyStatus status) {
    return _statuses.doc(status.id).set(status.toFirestore());
  }
}
