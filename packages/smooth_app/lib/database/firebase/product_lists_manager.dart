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

  Future<void> fetchUserProductLists() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> productLists =
        await FirebaseFirestore.instance
            .collection(_collectionName)
            .where('userID', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
            .get();

    if (productLists.docs.isEmpty) {
      return;
    }

    final LocalDatabase localDB = await LocalDatabase.getLocalDatabase(false);
    final DaoProductList daoProductList = DaoProductList(localDB);

    for (final QueryDocumentSnapshot<Map<String, dynamic>> productListDoc
        in productLists.docs) {
      final Map<int, List<ScannedBarcode>> barcodes =
          await _fetchProductListBarcodes(productListDoc.id);

      late ProductList productList;
      final String productListName = productListDoc['name'];
      if (productListName == ProductListType.HISTORY.key) {
        productList = ProductList.history();
      } else if (productListName == ProductListType.SCAN_HISTORY.key) {
        productList = ProductList.history();
      } else if (productListName == ProductListType.SCAN_SESSION.key) {
        productList = ProductList.scanHistory();
      } else {
        productList = ProductList.user(productListName);
      }

      productList.set(barcodes);
      daoProductList.put(productList);
    }
  }

  Future<Map<int, List<ScannedBarcode>>> _fetchProductListBarcodes(
      final String productListDocID) async {
    final Map<int, List<ScannedBarcode>> barcodes =
        <int, List<ScannedBarcode>>{};

    final QuerySnapshot<Map<String, dynamic>> storedBarcodes =
        await FirebaseFirestore.instance
            .collection(_getBarcodesSubCollectionPath(
                productListDocID: productListDocID))
            .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> i
        in storedBarcodes.docs) {
      final ScannedBarcode barcode = ScannedBarcode('').fromFirestore(i, null);
      final int scanDay = parseDateTimeAsScannedBarcodeKey(
          DateTime.fromMillisecondsSinceEpoch(barcode.lastScanTime));

      if (barcodes[scanDay] == null) {
        barcodes[scanDay] = <ScannedBarcode>[];
      }

      barcodes[scanDay]!.add(barcode);
    }

    return barcodes;
  }

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

  Future<void> clearProductList({
    required final ProductList productList,
    required final Map<int, List<ScannedBarcode>> barcodes,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> productLists =
        await _getProductLists(productList: productList);
    if (productLists.docs.isEmpty) {
      return;
    }

    final String productListDocID = productLists.docs.first.id;

    // To remove the barcodes subcollection, all documents within it must be deleted.
    final String barcodesSubcollection =
        _getBarcodesSubCollectionPath(productListDocID: productListDocID);
    for (final List<ScannedBarcode> i in barcodes.values) {
      for (final ScannedBarcode j in i) {
        await FirebaseFirestore.instance
            .collection(barcodesSubcollection)
            .doc(j.barcode)
            .delete();
      }
    }

    await FirebaseFirestore.instance
        .collection(_collectionName)
        .doc(productListDocID)
        .delete();
  }

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

  Future<void> _manageBarcode({
    required final ProductList productList,
    required final ScannedBarcode barcode,
    required final _FirebaseFirestoreActions action,
    final String newName = '',
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> productLists =
        await _getProductLists(productList: productList);

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
                  FirebaseAuth.instance.currentUser!.uid,
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
            documentId: barcode.barcode,
            data: barcode,
            merge: true,
          );
        }
        break;

      case _FirebaseFirestoreActions.delete:
        {
          final FirestoreService<ScannedBarcode> service =
              FirestoreService<ScannedBarcode>(
            collectionPath: _getBarcodesSubCollectionPath(
                productListDocID: productLists.docs.first.id),
            fromFirestore: ScannedBarcode('').fromFirestore,
          );

          await service.deleteDocument(documentId: barcode.barcode);
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

  // May only be called when a user is signed in
  Future<QuerySnapshot<Map<String, dynamic>>> _getProductLists({
    required final ProductList productList,
  }) async {
    final String productListName = _getProductListName(productList);
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .where('userID', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .where('name', isEqualTo: productListName)
        .get();
  }

  Future<String> _addProductList(
      final String productListName, final String userID) async {
    final Map<String, String> data = <String, String>{
      'name': productListName,
      'userID': userID,
    };

    final DocumentReference<Map<String, dynamic>> documentSnapshot =
        await FirebaseFirestore.instance.collection(_collectionName).add(data);

    return documentSnapshot.id;
  }

  String _getBarcodesSubCollectionPath({
    required final String productListDocID,
  }) =>
      '/$_collectionName/$productListDocID/$_barcodesSubCollectionName';

  String _getProductListName(final ProductList productList) =>
      productList.listType == ProductListType.USER
          ? productList.parameters
          : productList.listType.key;
}
