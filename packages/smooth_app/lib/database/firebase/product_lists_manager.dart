import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/database/dao_product_list.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/database/scanned_barcodes_manager.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';

enum _FirebaseFirestoreActions {
  add,
  delete,
  rename,
}

// Manages firestore CRUD operations for collection "product_lists"
class ProductListFirebaseManager {
  final String _collectionName = 'product_lists';
  final String _barcodesSubCollectionName = 'barcodes';

  /// Flag showing if the user's signed in.
  bool get _noUser => FirebaseAuth.instance.currentUser == null;

  /// Getter for the user's ID. Must be used only when a user's signed in.
  String get _userID => FirebaseAuth.instance.currentUser!.uid;

  Future<void> synchronizeWithLocal({
    required final LocalDatabase localDB,
  }) async {
    // START Debug
    final QuerySnapshot<Map<String, dynamic>> contributions =
        await FirebaseFirestore.instance
            .collection("contributions")
            .doc("sqVUmIpPfwjT5EZcM4qP")
            .collection("HTTP_USER_CONTRIBUTOR")
            .get();
    // END Debug
    if (_noUser) {
      return;
    }

    localDB.loadingFromFirebase = true;
    localDB.notifyListeners();

    final ScannedBarcodesMap firebaseBarcodes =
        await _fetchFirestoreStoredBarcodes(localDB: localDB);

    final ProductList history = ProductList.history();
    final DaoProductList daoProductList = DaoProductList(localDB);
    await daoProductList.get(history);

    final ScannedBarcodesMap localBarcodes = history.getList();

    /// Update local list
    final ScannedBarcodesMap newLocalBarcodes =
        ScannedBarcodesMap.from(localBarcodes);
    for (final MapEntry<int, LinkedHashSet<ScannedBarcode>> i
        in firebaseBarcodes.entries) {
      if (localBarcodes.containsKey(i.key)) {
        newLocalBarcodes[i.key]!.addAll(i.value);
      } else {
        newLocalBarcodes[i.key] = LinkedHashSet<ScannedBarcode>.from(i.value);
      }
    }

    history.set(newLocalBarcodes);
    await daoProductList.put(history);

    /// Update firebase' list
    for (final MapEntry<int, LinkedHashSet<ScannedBarcode>> i
        in localBarcodes.entries) {
      if (firebaseBarcodes.containsKey(i.key)) {
        for (final ScannedBarcode j in i.value) {
          if (firebaseBarcodes[i.key]!.contains(j)) {
            continue;
          }

          await addBarcode(productList: history, barcode: j);
        }
        continue;
      }

      for (final ScannedBarcode j in i.value) {
        await addBarcode(productList: history, barcode: j);
      }
    }

    localDB.loadingFromFirebase = false;
    localDB.notifyListeners();
  }

  Future<ScannedBarcodesMap> _fetchFirestoreStoredBarcodes({
    required final LocalDatabase localDB,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> productList =
        await _getProductList(productList: ProductList.history());

    if (productList.docs.isEmpty) {
      return <int, LinkedHashSet<ScannedBarcode>>{};
    }

    final ScannedBarcodesMap fetchedBarcodes =
        <int, LinkedHashSet<ScannedBarcode>>{};

    final QuerySnapshot<Map<String, dynamic>> storedBarcodes =
        await FirebaseFirestore.instance
            .collection(_getBarcodesSubCollectionPath(
              productListDocID: productList.docs.first.id,
            ))
            .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> i
        in storedBarcodes.docs) {
      final ScannedBarcode barcode = ScannedBarcode('').fromFirestore(i, null);
      final int scanDay = parseDateTimeAsScannedBarcodeKey(
        DateTime.fromMillisecondsSinceEpoch(barcode.lastScanTime),
      );

      fetchedBarcodes[scanDay] ??= LinkedHashSet<ScannedBarcode>();
      fetchedBarcodes[scanDay]!.add(barcode);
    }

    return fetchedBarcodes;
  }

  /// Adds [barcode] to [productList] barcodes subcollection in Firebase Firestore.
  Future<void> addBarcode({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageBarcode(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.add,
    );
  }

  /// Deletes [barcode] from [productList] barcodes subcollection in Firebase Firestore.
  Future<void> deleteBarcode({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageBarcode(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.delete,
    );
  }

  /// Renames [productList] to [newName] in Firebase Firestore.
  Future<void> renameProductList({
    required final ProductList productList,
    required final String newName,
  }) async {
    await _manageBarcode(
      productList: productList,
      barcode: ScannedBarcode(''),
      action: _FirebaseFirestoreActions.rename,
      newName: newName,
    );
  }

  /// Handles any [action] related to [barcode] in [productList] barcodes subcollection in Firebase Firestore.
  Future<void> _manageBarcode({
    required final ProductList productList,
    required final ScannedBarcode barcode,
    required final _FirebaseFirestoreActions action,
    final String newName = '',
  }) async {
    if (_noUser) {
      return;
    }

    // iliyan03: Currently working only with history list
    if (productList.listType != ProductListType.HISTORY) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> productLists =
        await _getProductList(productList: productList);

    if (productLists.docs.isEmpty &&
        action == _FirebaseFirestoreActions.delete) {
      return;
    }

    switch (action) {
      case _FirebaseFirestoreActions.add:
        {
          final String productListDocID = productLists.docs.isEmpty
              ? await _addProductList(
                  _getProductListName(productList),
                  _userID,
                )
              : productLists.docs.first.id;

          final String barcodesSubcollectionPath =
              _getBarcodesSubCollectionPath(productListDocID: productListDocID);

          final FirestoreService<ScannedBarcode> service =
              FirestoreService<ScannedBarcode>(
            collectionPath: barcodesSubcollectionPath,
            fromFirestore: ScannedBarcode('').fromFirestore,
          );

          await service.setDocument(
            data: barcode,
            documentId: _getDocID(barcode),
            merge: true,
          );
        }
        break;

      case _FirebaseFirestoreActions.delete:
        {
          final String barcodesSubcollectionPath =
              _getBarcodesSubCollectionPath(
            productListDocID: productLists.docs.first.id,
          );

          await FirebaseFirestore.instance
              .collection(barcodesSubcollectionPath)
              .doc(_getDocID(barcode))
              .delete();
        }
        break;

      case _FirebaseFirestoreActions.rename:
        {
          if (newName.isEmpty) {
            return;
          }

          await FirebaseFirestore.instance
              .collection(_collectionName)
              .doc(productLists.docs.first.id)
              .update(<String, String>{'name': newName});
        }
        break;
    }
  }

  /// Gets [productList] doc for the signed in user. Must be used only when a user's signed in.
  Future<QuerySnapshot<Map<String, dynamic>>> _getProductList({
    required final ProductList productList,
  }) async {
    final String productListName = _getProductListName(productList);
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .where('userID', isEqualTo: _userID)
        .where('name', isEqualTo: productListName)
        .get();
  }

  /// Adds [productList] to Firebase Firestore for user with [userID].
  Future<String> _addProductList(
    final String productListName,
    final String userID,
  ) async {
    final Map<String, String> data = <String, String>{
      'name': productListName,
      'userID': userID,
    };

    final DocumentReference<Map<String, dynamic>> documentSnapshot =
        await FirebaseFirestore.instance.collection(_collectionName).add(data);

    return documentSnapshot.id;
  }

  /// Returns the formatted path to the barcodes subcollection of product lists doc with ID of [productListDocID].
  String _getBarcodesSubCollectionPath({
    required final String productListDocID,
  }) =>
      '/$_collectionName/$productListDocID/$_barcodesSubCollectionName';

  /// Gets [productList] list name
  String _getProductListName(final ProductList productList) =>
      productList.listType == ProductListType.USER
          ? productList.parameters
          : productList.listType.key;

  /// Returns the formatted [barcode] document ID.
  String _getDocID(final ScannedBarcode barcode) {
    return '${barcode.barcode}_${barcode.lastScanTime}';
  }
}
