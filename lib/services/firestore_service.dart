import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference _applications = _db.collection('applications');

  static Stream<List<LoanApplication>> streamApplications() {
    return _applications
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
          final list = <LoanApplication>[];
          for (var doc in snapshot.docs) {
            try {
              list.add(LoanApplication.fromFirestore(doc));
            } catch (_) {}
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  static Stream<LoanApplication> streamApplicationById(String id) {
    return _applications.doc(id).snapshots(includeMetadataChanges: false).map((doc) => LoanApplication.fromFirestore(doc));
  }

  static Future<String> createApplication(Map<String, dynamic> data) async {
    final doc = await _applications.add(data);
    return doc.id;
  }

  static Future<void> updateStatus(String id, String status) async {
    await _applications.doc(id).update({'status': status});
  }
}
