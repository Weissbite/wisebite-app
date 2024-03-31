import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_app/data_models/firestore_model.dart';

class FirestoreService<T extends FirestoreModel<T>> {
  FirestoreService({
    required this.collectionPath,
    required this.fromFirestore,
  });
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final T Function(
    DocumentSnapshot<Map<String, dynamic>>,
    SnapshotOptions? options,
  ) fromFirestore;
  String collectionPath;

  /// Gets a document by its ID.
  Future<T?> getDocument({required String documentId}) async {
    final DocumentReference<T> documentReference =
        _getDocumentWithConverter(documentId: documentId);
    final DocumentSnapshot<T> documentSnapshot = await documentReference.get();

    if (documentSnapshot.exists) {
      return documentSnapshot.data();
    } else {
      return null;
    }
  }

  /// Sets or merges data in a document.
  Future<void> setDocument({
    required String documentId,
    required T data,
    bool merge = false,
  }) async {
    final DocumentReference<T> documentReference =
        _getDocumentWithConverter(documentId: documentId);

    await documentReference.set(data, SetOptions(merge: merge));
  }

  Future<void> deleteDocument({
    required String documentId,
  }) async {
    await _firestore.collection(collectionPath).doc(documentId).delete();
  }

  // Method to get a document reference with a converter
  DocumentReference<T> _getDocumentWithConverter({required String documentId}) {
    return _firestore
        .collection(collectionPath)
        .doc(documentId)
        .withConverter<T>(
          fromFirestore: fromFirestore,
          toFirestore: (T model, _) => model.toFirestore(),
        );
  }
}
