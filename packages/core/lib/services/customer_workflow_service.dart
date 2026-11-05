import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerWorkflowService {
  final FirebaseFirestore db;
  CustomerWorkflowService({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;
  Stream<List<Map<String, dynamic>>> watchExtensions(String id) => db
      .collection('requests')
      .where('sessionId', isEqualTo: id)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['type'] == 'extend_session')
          .map((d) => {'id': d.id, ...d.data()})
          .toList());
  Stream<List<Map<String, dynamic>>> watchTakeaways(String uid) => db
          .collection('sessions')
          .doc('takeaway_orders')
          .collection('orders')
          .where('createdBy', isEqualTo: uid)
          .snapshots()
          .map((s) {
        final rows = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        rows.sort((a, b) => (b['createdAt'] as Timestamp)
            .compareTo(a['createdAt'] as Timestamp));
        return rows;
      });
  Stream<List<Map<String, dynamic>>> watchPreorders() => db
      .collection('reservations')
      .where('status', isEqualTo: 'confirmed')
      .snapshots()
      .map((s) => s.docs
          .where((d) => (d.data()['preOrderItems'] as List? ?? []).isNotEmpty)
          .map((d) => {'id': d.id, ...d.data()})
          .toList());
  Future<void> reviewPreorder(String id, String staffId) =>
      db.runTransaction((tx) async {
        final ref = db.collection('reservations').doc(id);
        final doc = await tx.get(ref);
        if (!doc.exists || doc.data()!['status'] != 'confirmed')
          throw StateError('Đặt bàn không còn chờ nhận.');
        tx.update(ref, {
          'preorderReviewedBy': staffId,
          'preorderReviewedAt': FieldValue.serverTimestamp()
        });
      });
}

final customerWorkflowServiceProvider =
    Provider((ref) => CustomerWorkflowService());
final extensionRequestsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, id) =>
        ref.watch(customerWorkflowServiceProvider).watchExtensions(id));
final customerTakeawaysProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, id) =>
        ref.watch(customerWorkflowServiceProvider).watchTakeaways(id));
final preorderTasksProvider = StreamProvider(
    (ref) => ref.watch(customerWorkflowServiceProvider).watchPreorders());
