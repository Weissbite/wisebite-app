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
import 'package:smooth_app/query/product_query.dart';
import 'package:smooth_app/services/smooth_services.dart';

enum _FirebaseFirestoreActions {
  add,
  update,
}

// Manages Firestore CRUD operations for collection "contributions"
class ContributionsFirebaseManager extends ProductListSupplier {
  ContributionsFirebaseManager(final PagedProductQuery productQuery, final LocalDatabase localDatabase)
      : super(productQuery, localDatabase);

  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static bool get _noUser => FirebaseAuth.instance.currentUser == null;

  static String get _userId => FirebaseAuth.instance.currentUser!.uid;

  static const String _collectionName = 'contributions';

  @override
  Future<String?> asyncLoad() async {
    final QuerySnapshot<Map<String, dynamic>>? contributions =
        await fetchUserContributions(productListType: productQuery.getProductList().listType.key);

    if (contributions!.docs.isNotEmpty) {
      try {
        // final ScannedBarcodesMap barcodes =
        //     <int, LinkedHashSet<ScannedBarcode>>{};
        // barcodes[0] ??= LinkedHashSet<ScannedBarcode>();

        final List<Product> products = [];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> contrib in contributions.docs) {
          // barcodes[0]!.add(ScannedBarcode(element.get('barcode')));
          final FetchedProduct fetchedProduct = await ProductRefresher().silentFetchAndRefresh(
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
      } catch (e) {
        return e.toString();
      }
    }

    return null;
  }

  @override
  ProductListSupplier? getRefreshSupplier() => null;

  static Future<QuerySnapshot<Map<String, dynamic>>?> fetchUserContributions({
    required final String productListType,
  }) async {
    if (_noUser) {
      return null;
    }

    final OpenFoodFactsLanguage offLanguage = ProductQuery.getLanguage();
    final QuerySnapshot<Map<String, dynamic>> contributions = await firestore
        .collection(_collectionName)
        .doc(_userId)
        .collection(productListType)
        .where('language', isEqualTo: offLanguage.offTag)
        .get();

    return contributions;
  }

  static Future<void> addContribution({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageContributions(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.add,
    );
  }

  static Future<void> updateContribution({
    required final ProductList productList,
    required final ScannedBarcode barcode,
  }) async {
    await _manageContributions(
      productList: productList,
      barcode: barcode,
      action: _FirebaseFirestoreActions.update,
    );
  }

  static Future<void> _manageContributions({
    required final ProductList productList,
    required final ScannedBarcode barcode,
    required final _FirebaseFirestoreActions action,
  }) async {
    if (_noUser) {
      return;
    }

    final QuerySnapshot<Map<String, dynamic>>? contributions =
        await fetchUserContributions(productListType: productList.listType.key);

    if (contributions!.docs.isEmpty) {
      return;
    }

    final OpenFoodFactsLanguage offLanguage = ProductQuery.getLanguage();

    switch (action) {
      case _FirebaseFirestoreActions.add:
        final int now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, dynamic> doc = <String, dynamic>{
          'barcode': barcode.barcode,
          'created': now,
          'modified': now,
          'language': offLanguage.offTag,
          'type': productList.listType.key,
        };
        firestore
            .collection(_getBarcodesSubCollectionPath(productList.listType.key))
            .doc(barcode.barcode)
            .set(doc)
            .onError((err, _) => Logs.e('Failed adding doc $err'));
        break;

      case _FirebaseFirestoreActions.update:
        final int now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, dynamic> doc = <String, dynamic>{
          'modified': now,
        };
        firestore
            .collection(_getBarcodesSubCollectionPath(productList.listType.key))
            .doc(barcode.barcode)
            .set(doc)
            .onError((err, _) => Logs.e('Failed adding doc $err'));

        break;
    }
  }

  // May only be called when a user is signed in
  Future<QuerySnapshot<Map<String, dynamic>>> _getProductLists({
    required final ProductList productList,
  }) async {
    final String productListName = _getProductListName(productList);
    return firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: _userId)
        .where('name', isEqualTo: productListName)
        .get();
  }

  Future<String> _addProductList(final String productListName, final String userId) async {
    final Map<String, String> data = <String, String>{
      'name': productListName,
      'userId': userId,
    };

    final DocumentReference<Map<String, dynamic>> documentSnapshot =
        await firestore.collection(_collectionName).add(data);

    return documentSnapshot.id;
  }

  static String _getBarcodesSubCollectionPath(String productListType) {
    return '/$_collectionName/$_userId/$productListType';
  }

  String _getProductListName(final ProductList productList) =>
      productList.listType == ProductListType.USER ? productList.parameters : productList.listType.key;

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
