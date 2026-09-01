import 'package:cloud_firestore/cloud_firestore.dart';

import 'gmail_sync.dart';

class Student {
  const Student({
    required this.uid,
    required this.vitEmail,
    required this.name,
    required this.neoId,
    required this.regNo,
    this.createdAt,
    this.fcmTokens = const <String>[],
    this.gmailSync = const GmailSync(),
  });

  final String uid;
  final String vitEmail;
  final String name;
  final String neoId;
  final String regNo;
  final DateTime? createdAt;
  final List<String> fcmTokens;
  final GmailSync gmailSync;

  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Student(
      uid: doc.id,
      vitEmail: data['vitEmail'] as String? ?? '',
      name: data['name'] as String? ?? '',
      neoId: data['neoId'] as String? ?? '',
      regNo: data['regNo'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      fcmTokens:
          (data['fcmTokens'] as List<dynamic>?)
              ?.map((token) => token.toString())
              .toList() ??
          const <String>[],
      gmailSync: GmailSync.fromMap(data['gmailSync'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'vitEmail': vitEmail,
      'name': name,
      'neoId': neoId,
      'regNo': regNo,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'fcmTokens': fcmTokens,
    };
  }
}
