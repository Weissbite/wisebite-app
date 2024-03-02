import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/database/dao_product_list.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';

enum FirebaseFirestoreActions {
  add,
  delete,
}

class ProductListFirebaseManager {
  final String _collectionName = 'product_lists';

  Future<void> fetchAllBarcodes() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    //Check if user has saved any scanned barcodes
    final DocumentReference<Map<String, dynamic>> docRef =
        FirebaseFirestore.instance.collection(_collectionName).doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
        await docRef.get();
    if (!documentSnapshot.exists) {
      return;
    }

    //Fetch all scanned barcodes/product lists and save them in memory
  }

  Future<void> addBarcode({
    required final ProductList productList,
    required final int scanDay,
    required final ScannedBarcode barcode,
  }) async {
    await _manageBarcode(
      productList: productList,
      scanDay: scanDay,
      barcode: barcode,
      action: FirebaseFirestoreActions.add,
    );
  }

  Future<void> deleteBarcode({
    required final ProductList productList,
    required final int scanDay,
    required final ScannedBarcode barcode,
  }) async {
    await _manageBarcode(
      productList: productList,
      scanDay: scanDay,
      barcode: barcode,
      action: FirebaseFirestoreActions.delete,
    );
  }

  /// The only way to delete an entire collection/subcollection is to retrieve all of it's docs and delete them
  Future<void> clearProductList({
    required final ProductList productList,
    required final Map<int, List<ScannedBarcode>> barcodes,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    for (final MapEntry<int, List<ScannedBarcode>> i in barcodes.entries) {
      for (final ScannedBarcode j in i.value) {
        await deleteBarcode(
          productList: productList,
          scanDay: i.key,
          barcode: j,
        );
      }
    }
  }

  Future<void> _manageBarcode({
    required final ProductList productList,
    required final int scanDay,
    required final ScannedBarcode barcode,
    required final FirebaseFirestoreActions action,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final String collectionPath = _getCollectionPath(
      productListName: _getProductListName(productList),
      scanDay: scanDay,
    );

    final FirestoreService<ScannedBarcode> service =
        FirestoreService<ScannedBarcode>(
      collectionPath: collectionPath,
      fromFirestore: ScannedBarcode('').fromFirestore,
    );

    switch (action) {
      case FirebaseFirestoreActions.add:
        {
          await service.setDocument(
            documentId: barcode.barcode,
            data: barcode,
            merge: true,
          );
        }
        break;

      case FirebaseFirestoreActions.delete:
        {
          await service.deleteDocument(
            collectionPath: collectionPath,
            documentId: barcode.barcode,
          );
        }
        break;
    }
  }

  String _getCollectionPath({
    required final String productListName,
    required final int scanDay,
  }) {
    final String userID = FirebaseAuth.instance.currentUser!.uid;
    return '/$_collectionName/$userID/lists/$productListName/days/$scanDay/barcodes';
  }

  String _getProductListName(final ProductList productList) =>
      productList.listType == ProductListType.USER
          ? productList.parameters
          : productList.listType.key;
}
