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

  Stream<Student?> watchStudent(String uid) {
    return _students
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? Student.fromFirestore(doc) : null);
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCompanyPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _companies
        .orderBy('registrationDeadline')
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.snapshots();
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
        .map(
          (doc) => doc.exists ? StudentCompanyStatus.fromFirestore(doc) : null,
        );
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

  Future<void> setRequirementCompleted({
    required String studentId,
    required String companyId,
    required String requirementId,
    required bool completed,
  }) {
    final id = StudentCompanyStatus.docIdFor(
      studentId: studentId,
      companyId: companyId,
    );
    return _statuses.doc(id).set(<String, dynamic>{
      'studentId': studentId,
      'companyId': companyId,
      'completedRequirementIds': completed
          ? FieldValue.arrayUnion(<String>[requirementId])
          : FieldValue.arrayRemove(<String>[requirementId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setOptedIn({
    required String studentId,
    required String companyId,
    required bool optedIn,
  }) {
    final id = StudentCompanyStatus.docIdFor(
      studentId: studentId,
      companyId: companyId,
    );
    return _statuses.doc(id).set(<String, dynamic>{
      'studentId': studentId,
      'companyId': companyId,
      'optedIn': optedIn,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
