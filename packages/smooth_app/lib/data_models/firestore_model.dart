import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreModel<T> {
  Map<String, dynamic> toFirestore();
  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> data,
    SnapshotOptions? options,
  );
}
