import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/inquiry.dart';
import '../../domain/repository/inquiry_repository.dart';

class FirestoreInquiryRepository implements InquiryRepository {
  final FirebaseFirestore _firestore;

  FirestoreInquiryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> sendInquiry(Inquiry inquiry) async {
    await _firestore.collection('inquiries').add({
      ...inquiry.toFirestore(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
