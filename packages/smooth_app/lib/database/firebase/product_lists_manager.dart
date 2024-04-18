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

  bool get _noUser => FirebaseAuth.instance.currentUser == null;
  String get _userID => FirebaseAuth.instance.currentUser!.uid;

  Future<void> fetchUserProductLists({
    required final LocalDatabase localDB,
  }) async {
    if (_noUser) {
      return;
    }

    localDB.loadingFromFirebase = true;
    localDB.notifyListeners();

    final QuerySnapshot<Map<String, dynamic>> productLists =
        await FirebaseFirestore.instance
            .collection(_collectionName)
            .where('userID', isEqualTo: _userID)
            .get();

    final DaoProductList daoProductList = DaoProductList(localDB);

    if (productLists.docs.isEmpty) {
      // Clearing all local data from the product lists, so there's no data inconsistency
      for (final ProductList i in _getAllProductLists(daoProductList)) {
        daoProductList.clear(i, false);
      }

      return;
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> productListDoc
        in productLists.docs) {
      final Map<int, List<ScannedBarcode>> barcodes =
          await _fetchProductListBarcodes(productListDoc.id);

      late ProductList productList;
      final String productListName = productListDoc['name'];
      if (productListName == ProductListType.HISTORY.key) {
        productList = ProductList.history();
      } else if (productListName == ProductListType.SCAN_HISTORY.key) {
        productList = ProductList.scanHistory();
      } else if (productListName == ProductListType.SCAN_SESSION.key) {
        productList = ProductList.scanSession();
      } else {
        productList = ProductList.user(productListName);
      }

      productList.set(barcodes);
      daoProductList.put(productList);
    }

    localDB.loadingFromFirebase = false;
    localDB.notifyListeners();
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
    // TODO(ILIYAN03): Currently there's no functionality for clearing a product list
    // if (_noUser) {
    //   return;
    // }
    //
    // final QuerySnapshot<Map<String, dynamic>> productLists =
    //     await _getProductLists(productList: productList);
    // if (productLists.docs.isEmpty) {
    //   return;
    // }
    //
    // final String productListDocID = productLists.docs.first.id;
    //
    // // To remove the barcodes subcollection, all documents within it must be deleted.
    // TODO(iliyan03): Could use WriteBatch for deleting multiple docs at once
    // final String barcodesSubcollection =
    //     _getBarcodesSubCollectionPath(productListDocID: productListDocID);
    // for (final List<ScannedBarcode> i in barcodes.values) {
    //   for (final ScannedBarcode j in i) {
    //     await FirebaseFirestore.instance
    //         .collection(barcodesSubcollection)
    //         .doc(j.barcode)
    //         .delete();
    //   }
    // }
    //
    // await FirebaseFirestore.instance
    //     .collection(_collectionName)
    //     .doc(productListDocID)
    //     .delete();

    return;
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

  Future<void> saveAllProductLists({
    required final LocalDatabase localDB,
  }) async {
    if (_noUser) {
      return;
    }

    localDB.loadingFromFirebase = true;
    localDB.notifyListeners();

    final DaoProductList daoProductList = DaoProductList(localDB);

    final List<ProductList> productLists = _getAllProductLists(daoProductList);
    for (final ProductList productList in productLists) {
      await daoProductList.get(productList);

      for (final List<ScannedBarcode> barcodes
          in productList.getList().values) {
        for (final ScannedBarcode i in barcodes) {
          await addBarcode(productList: productList, barcode: i);
        }
      }
    }

    localDB.loadingFromFirebase = false;
    localDB.notifyListeners();
  }

  Future<void> _manageBarcode({
    required final ProductList productList,
    required final ScannedBarcode barcode,
    required final _FirebaseFirestoreActions action,
    final String newName = '',
  }) async {
    if (_noUser) {
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

          final QuerySnapshot<Map<String, dynamic>> querySnapshot =
              await FirebaseFirestore.instance
                  .collection(barcodesSubcollectionPath)
                  .where('barcode', isEqualTo: barcode.barcode)
                  .where('last_scan_time', isEqualTo: barcode.lastScanTime)
                  .get();

          if (querySnapshot.docs.isEmpty) {
            break;
          }

          final String barcodeDocumentID = querySnapshot.docs.first.id;

          await FirebaseFirestore.instance
              .collection(barcodesSubcollectionPath)
              .doc(barcodeDocumentID)
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

  // May only be called when a user is signed in
  Future<QuerySnapshot<Map<String, dynamic>>> _getProductLists({
    required final ProductList productList,
  }) async {
    final String productListName = _getProductListName(productList);
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .where('userID', isEqualTo: _userID)
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

  List<ProductList> _getAllProductLists(DaoProductList daoProductList) {
    final List<String> userLists = daoProductList.getUserLists();
    final List<ProductList> productLists = <ProductList>[
      ProductList.scanSession(),
      ProductList.scanHistory(),
      ProductList.history(),
    ];

    for (final String userList in userLists) {
      productLists.add(ProductList.user(userList));
    }

    return productLists;
  }
}
