import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/fetched_product.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/data_models/product_list_supplier.dart';
import 'package:smooth_app/database/dao_product.dart';
import 'package:smooth_app/database/dao_product_list.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/pages/product/common/product_refresher.dart';
import 'package:smooth_app/query/paged_product_query.dart';
import 'package:smooth_app/query/paged_user_product_query.dart';
import 'package:smooth_app/query/product_query.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';

enum _FirebaseFirestoreActions {
  add,
  delete,
  rename,
}

// Manages Firestore CRUD operations for collection "contributions"
class ContributionsFirebaseManager extends ProductListSupplier {
  ContributionsFirebaseManager(
      final PagedProductQuery productQuery, final LocalDatabase localDatabase)
      : super(productQuery, localDatabase);

  bool get _noUser => FirebaseAuth.instance.currentUser == null;

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  final String _collectionName = 'contributions';

  @override
  Future<String?> asyncLoad() async {
    final PagedUserProductQuery query = productQuery as PagedUserProductQuery;
    final QuerySnapshot<Map<String, dynamic>>? contributions =
        await fetchUserContributions(type: query.type);

    if (contributions!.docs.isNotEmpty) {
      try {
        // final ScannedBarcodesMap barcodes =
        //     <int, LinkedHashSet<ScannedBarcode>>{};
        // barcodes[0] ??= LinkedHashSet<ScannedBarcode>();

        final List<Product> products = [];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> contrib
            in contributions.docs) {
          // barcodes[0]!.add(ScannedBarcode(element.get('barcode')));
          final FetchedProduct fetchedProduct =
              await ProductRefresher().silentFetchAndRefresh(
            barcode: contrib.get('barcode'),
            localDatabase: localDatabase,
          );

          if (fetchedProduct.product != null) {
            products.add(fetchedProduct.product!);
          }
        }

        final ProductList productList = productQuery.getProductList();
        if (products.isNotEmpty) {
          productList.setAll(products);
          productList.totalSize = products.length;
          partialProductList.add(productList);
          await DaoProduct(localDatabase).putAll(
            products,
            productQuery.language,
          );
        }

        await DaoProductList(localDatabase).put(productList);
        return null;

        // final ProductList productList = productQuery.getProductList();
        // productList.addAll(barcodes);

        await DaoProductList(localDatabase).put(productList);
      } catch (e) {
        return e.toString();
      }
    }

    return null;
  }

  @override
  ProductListSupplier? getRefreshSupplier() {
    // TODO: implement getRefreshSupplier
    throw UnimplementedError();
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> fetchUserContributions({
    required final UserSearchType type,
  }) async {
    if (_noUser) {
      return null;
    }

    final OpenFoodFactsLanguage offLanguage = ProductQuery.getLanguage();
    final QuerySnapshot<Map<String, dynamic>> contributions =
        await FirebaseFirestore.instance
            .collection(_collectionName)
            .doc(_userId)
            .collection(type.toString())
            .where('language', isEqualTo: offLanguage.offTag)
            .get();

    return contributions;

    /*
    final PagedProductQuery pagedUserProductQuery = PagedUserProductQuery(
      userId: _userId,
      type: type,
    );

    // TODO(yavor): Not sure if the @timestamp value matters. Setting it to "0" for now and will evaluate its impact.
    final ProductListSupplier dbProductListSupplier = DatabaseProductListSupplier(pagedUserProductQuery, localDB, 0);
    late ProductList productList;
    if (ProductListType.HTTP_USER_CONTRIBUTOR == type) {
      productList = ProductList.contributor(_userId,
          pageSize: pageSize, pageNumber: pageNumber, language: offLanguage);
    } else if (type == ProductListType.HTTP_USER_INFORMER) {
      productList = ProductList.informer(_userId,
          pageSize: pageSize, pageNumber: pageNumber, language: language);
    } else if (type == ProductListType.HTTP_USER_PHOTOGRAPHER) {
      productList = ProductList.photographer(_userId,
          pageSize: pageSize, pageNumber: pageNumber, language: language);
    } else {
      productList = ProductList.user(type.key);
    }

    productList.set(contributionBarcode);
    daoProductList.put(productList);

    localDB.loadingFromFirebase = false;
    localDB.notifyListeners();
     */
  }

  Future<void> addContribution({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageContributions(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.add,
    );
  }

  Future<void> deleteContribution({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageContributions(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.delete,
    );
  }

  Future<void> _manageContributions({
    required final ProductList productList,
    required final ScannedBarcode barcode,
    required final _FirebaseFirestoreActions action,
    final String newName = '',
  }) async {
    if (_noUser) {
      return;
    }

    final PagedUserProductQuery query = productQuery as PagedUserProductQuery;
    final QuerySnapshot<Map<String, dynamic>>? contributions =
        await fetchUserContributions(type: query.type);

    if (contributions!.docs.isEmpty &&
        action == _FirebaseFirestoreActions.delete) {
      return;
    }

    switch (action) {
      case _FirebaseFirestoreActions.add:
        final String productListDocID = contributions.docs.isEmpty
            ? await _addProductList(
                _getProductListName(productList),
                _userId,
              )
            : contributions.docs.first.id;

        final String barcodesSubcollectionPath =
            _getBarcodesSubCollectionPath();

        final FirestoreService<ScannedBarcode> service =
            FirestoreService<ScannedBarcode>(
          collectionPath: barcodesSubcollectionPath,
          fromFirestore: ScannedBarcode('').fromFirestore,
        );

        await service.setDocument(
          data: barcode,
          merge: true,
        );
        break;

      case _FirebaseFirestoreActions.delete:
        {
          final String barcodesSubcollectionPath =
              _getBarcodesSubCollectionPath();

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
              .collection(_getBarcodesSubCollectionPath())
              .doc(barcode.barcode)
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
        .where('userId', isEqualTo: _userId)
        .where('name', isEqualTo: productListName)
        .get();
  }

  Future<String> _addProductList(
      final String productListName, final String userId) async {
    final Map<String, String> data = <String, String>{
      'name': productListName,
      'userId': userId,
    };

    final DocumentReference<Map<String, dynamic>> documentSnapshot =
        await FirebaseFirestore.instance.collection(_collectionName).add(data);

    return documentSnapshot.id;
  }

  String _getBarcodesSubCollectionPath() {
    final PagedUserProductQuery query = productQuery as PagedUserProductQuery;
    final UserSearchType searchType = query.type;
    return '/$_collectionName/$_userId/$searchType';
  }

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
