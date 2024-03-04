import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/firestore_model.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/database/abstract_dao.dart';
import 'package:smooth_app/database/dao_product.dart';
import 'package:smooth_app/database/firebase/product_lists_manager.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/database/scanned_barcodes_manager.dart';

/// "Total size" fake value for lists that are not partial/paged.
const int _uselessTotalSizeValue = 0;

/// Transport class for a scanned barcode.
class ScannedBarcode extends FirestoreModel<ScannedBarcode> {
  ScannedBarcode(this._barcode, [this._lastScanTime = 0]) {
    if (_lastScanTime <= 0) {
      _lastScanTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  ScannedBarcode fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> data,
    SnapshotOptions? options,
  ) {
    final Map<String, dynamic>? barcode = data.data();
    return ScannedBarcode(
      barcode!['barcode'],
      barcode['last_scan_time'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'barcode': _barcode,
      'last_scan_time': _lastScanTime,
    };
  }

  String get barcode => _barcode;
  int get lastScanTime => _lastScanTime;

  late int _lastScanTime;
  final String _barcode;
}

// Can be generated automatically
class ScannedBarcodeAdapter extends TypeAdapter<ScannedBarcode> {
  @override
  final int typeId = 3;

  @override
  ScannedBarcode read(BinaryReader reader) {
    return ScannedBarcode(reader.readString(), reader.readInt());
  }

  @override
  void write(BinaryWriter writer, ScannedBarcode obj) {
    writer.writeString(obj.barcode);
    writer.writeInt(obj.lastScanTime);
  }
}

/// An immutable barcode list; e.g. my search yesterday about "Nutella"
class _BarcodeList {
  const _BarcodeList(
    this.timestamp,
    this.barcodes,
    this.totalSize,
  );

  _BarcodeList.now(final Map<int, List<ScannedBarcode>> barcodes)
      : this(
          LocalDatabase.nowInMillis(),
          barcodes,
          _uselessTotalSizeValue,
        );

  _BarcodeList.fromProductList(final ProductList productList)
      : this(
          LocalDatabase.nowInMillis(),
          productList.barcodes,
          productList.totalSize,
        );

  /// Freshness indicator: last time the list was updated.
  ///
  /// In milliseconds since epoch.
  /// Can be used to decide if the data is recent enough or deprecated.
  final int timestamp;
  final Map<int, List<ScannedBarcode>> barcodes;

  /// Total size of server query results (or 0).
  final int totalSize;
}

/// Hive type adapter for [_BarcodeList]
class _BarcodeListAdapter extends TypeAdapter<_BarcodeList> {
  @override
  final int typeId = 0;

  @override
  _BarcodeList read(BinaryReader reader) {
    final int timestamp = reader.readInt();
    final Map<dynamic, dynamic> barcodeMap = reader.readMap();

    final Map<int, List<ScannedBarcode>> barcodes =
        <int, List<ScannedBarcode>>{};
    for (final int i in barcodeMap.keys) {
      barcodes[i] = List<ScannedBarcode>.from(barcodeMap[i]);
    }

    late int totalSize;
    try {
      totalSize = reader.readInt();
    } catch (e) {
      totalSize = _uselessTotalSizeValue;
    }
    return _BarcodeList(timestamp, barcodes, totalSize);
  }

  @override
  void write(BinaryWriter writer, _BarcodeList obj) {
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.barcodes);
    writer.writeInt(obj.totalSize);
  }
}

class DaoProductList extends AbstractDao {
  DaoProductList(final LocalDatabase localDatabase) : super(localDatabase);

  static const String _hiveBoxName = 'barcodeLists';
  static const String _keySeparator = '::';

  @override
  Future<void> init() async => Hive.openLazyBox<_BarcodeList>(_hiveBoxName);

  @override
  void registerAdapter() {
    Hive.registerAdapter(_BarcodeListAdapter());
    Hive.registerAdapter(ScannedBarcodeAdapter());
  }

  LazyBox<_BarcodeList> _getBox() => Hive.lazyBox<_BarcodeList>(_hiveBoxName);

  Future<_BarcodeList?> _get(final ProductList productList) async {
    final _BarcodeList? result = await _getBox().get(getKey(productList));
    if (result != null) {
      localDatabase.upToDateProductList.setLocalUpToDate(
        getKey(productList),
        result.barcodes,
      );
    }
    return result;
  }

  Future<int?> getTimestamp(final ProductList productList) async =>
      (await _get(productList))?.timestamp;

  // Why the "base64" part? Because of #753!
  // "HiveError: String keys need to be ASCII Strings with a max length of 255"
  // Encoding the parameter part in base64 makes us safe regarding ASCII.
  // As it's a list of keywords, there's a fairly high probability
  // that we'll be under the 255 character length.
  static String getKey(final ProductList productList) =>
      '${productList.listType.key}'
      '$_keySeparator'
      '${base64.encode(utf8.encode(productList.getParametersKey()))}';

  static String getProductListParameters(final String key) {
    final int pos = key.indexOf(_keySeparator);
    if (pos < 0) {
      throw Exception('Unknown key format without "$_keySeparator": $key');
    }
    if (pos + _keySeparator.length == key.length) {
      return '';
    }
    final String tmp = key.substring(pos + _keySeparator.length);
    return utf8.decode(base64.decode(tmp));
  }

  static ProductListType getProductListType(final String key) {
    final int pos = key.indexOf(_keySeparator);
    if (pos < 0) {
      throw Exception('Unknown key format without "$_keySeparator": $key');
    }
    final String value = key.substring(0, pos);
    for (final ProductListType productListType in ProductListType.values) {
      if (productListType.key == value) {
        return productListType;
      }
    }
    throw Exception('Unknown product list type: "$value" from "$key"');
  }

  Future<void> _put(final String key, final _BarcodeList barcodeList) async {
    await _getBox().put(key, barcodeList);
    localDatabase.upToDateProductList.setLocalUpToDate(
      key,
      barcodeList.barcodes,
    );
  }

  Future<void> put(final ProductList productList) async =>
      _put(getKey(productList), _BarcodeList.fromProductList(productList));

  Future<bool> delete(
    final ProductList productList, {
    final bool rename = false,
  }) async {
    final LazyBox<_BarcodeList> box = _getBox();
    final String key = getKey(productList);
    localDatabase.upToDateProductList
        .setLocalUpToDate(key, <int, List<ScannedBarcode>>{});
    if (!box.containsKey(key)) {
      return false;
    }

    // We don't want the product list to get deleted from the Firestore upon renaming
    if (!rename) {
      await ProductListFirebaseManager().clearProductList(
        productList: productList,
        barcodes: productList.barcodes,
      );
    }

    await box.delete(key);
    return true;
  }

  /// Loads the barcode list.
  Future<void> get(final ProductList productList) async {
    final _BarcodeList? list = await _get(productList);
    final Map<int, List<ScannedBarcode>> barcodes =
        <int, List<ScannedBarcode>>{};
    productList.totalSize = list?.totalSize ?? 0;
    if (list == null || list.barcodes.isEmpty) {
      productList.set(barcodes);
      return;
    }
    productList.set(list.barcodes);
  }

  /// Checks if a list exists in the database.
  bool exist(final ProductList productList) =>
      _getBox().containsKey(getKey(productList));

  /// Returns the number of barcodes quickly but without product check.
  Future<int> getLength(final ProductList productList) async {
    final _BarcodeList? list = await _get(productList);
    if (list == null || list.barcodes.isEmpty) {
      return 0;
    }
    return list.barcodes.length;
  }

  /// Moves a barcode to the end of the list.
  ///
  /// One barcode duplicate is potentially removed:
  /// * If the barcode was already there, it's moved to the end of the list.
  /// * If the barcode wasn't there, it's added to the end of the list.
  Future<void> push(
    final ProductList productList,
    final ScannedBarcode barcode,
  ) async {
    final Map<int, List<ScannedBarcode>> barcodes;

    final _BarcodeList? list = await _get(productList);
    if (list == null) {
      barcodes = <int, List<ScannedBarcode>>{};
    } else {
      barcodes = _getSafeBarcodeListCopy(list.barcodes);
    }

    if (barcodes.isNotEmpty) {
      barcodeExists(
        barcodes,
        barcode.barcode,
        (
          ScannedBarcode foundBarcode,
          List<ScannedBarcode> foundBarcodeList,
          int foundInDay,
        ) async {
          foundBarcodeList.remove(foundBarcode);
          await ProductListFirebaseManager().deleteBarcode(
            productList: productList,
            barcode: barcode,
          );
        },
      );
    }

    final int today = getTodayDateAsScannedBarcodeKey();
    if (barcodes[today] == null) {
      barcodes[today] = <ScannedBarcode>[];
    }

    barcodes[today]!.add(barcode);
    await _put(getKey(productList), _BarcodeList.now(barcodes));
    await ProductListFirebaseManager().addBarcode(
      productList: productList,
      barcode: barcode,
    );
  }

  Future<void> clear(final ProductList productList) async {
    final _BarcodeList newList =
        _BarcodeList.now(<int, List<ScannedBarcode>>{});
    await ProductListFirebaseManager().clearProductList(
      productList: productList,
      barcodes: productList.barcodes,
    );
    await _put(getKey(productList), newList);
  }

  /// Adds or removes a barcode within a product list (depending on [include])
  ///
  /// Returns true if there was a change in the list.
  Future<bool> set(
    final ProductList productList,
    final String barcode,
    final bool include,
  ) async {
    final _BarcodeList? list = await _get(productList);
    final Map<int, List<ScannedBarcode>> barcodes;
    if (list == null) {
      barcodes = <int, List<ScannedBarcode>>{};
    } else {
      barcodes = _getSafeBarcodeListCopy(list.barcodes);
    }

    final bool found = barcodeExists(barcodes, barcode, (
      ScannedBarcode foundBarcode,
      List<ScannedBarcode> foundBarcodeList,
      int foundInDay,
    ) async {
      if (!include) {
        foundBarcodeList.remove(foundBarcode);
        await ProductListFirebaseManager().deleteBarcode(
          productList: productList,
          barcode: foundBarcode,
        );
      }
    });

    if (found) {
      if (include) {
        return false;
      }

      // There's no need to do anything here because we've already removed the barcode when we searched for it.
    } else {
      if (!include) {
        return false;
      }

      final ScannedBarcode newBarcode = ScannedBarcode(barcode);
      List<ScannedBarcode>? todayScannedBarcodes =
          barcodes[getTodayDateAsScannedBarcodeKey()];
      if (todayScannedBarcodes != null) {
        todayScannedBarcodes.add(newBarcode);
      } else {
        todayScannedBarcodes = <ScannedBarcode>[newBarcode];
      }

      await ProductListFirebaseManager().addBarcode(
        productList: productList,
        barcode: newBarcode,
      );
    }

    final _BarcodeList newList = _BarcodeList.now(barcodes);
    await _put(getKey(productList), newList);
    return true;
  }

  /// Adds or removes list of barcodes to/from a [productList] in one go (depending on [include])
  Future<void> bulkSet(
    final ProductList productList,
    final List<String> barcodes, {
    final bool include = true,
  }) async {
    final _BarcodeList? list = await _get(productList);
    final Map<int, List<ScannedBarcode>> allBarcodes;

    if (list == null) {
      allBarcodes = <int, List<ScannedBarcode>>{};
    } else {
      allBarcodes = _getSafeBarcodeListCopy(list.barcodes);
    }

    for (final String barcode in barcodes) {
      if (include) {
        final ScannedBarcode newBarcode = ScannedBarcode(barcode);
        if (allBarcodes[getTodayDateAsScannedBarcodeKey()] == null) {
          allBarcodes[getTodayDateAsScannedBarcodeKey()] = <ScannedBarcode>[
            newBarcode
          ];
        } else {
          allBarcodes[getTodayDateAsScannedBarcodeKey()]!.add(newBarcode);
        }

        await ProductListFirebaseManager().addBarcode(
          productList: productList,
          barcode: newBarcode,
        );
      } else {
        barcodeExists(allBarcodes, barcode, (
          final ScannedBarcode foundBarcode,
          final List<ScannedBarcode> foundBarcodeList,
          int foundInDay,
        ) async {
          foundBarcodeList.remove(foundBarcode);
          await ProductListFirebaseManager().deleteBarcode(
            productList: productList,
            barcode: foundBarcode,
          );
        });
      }
    }

    final _BarcodeList newList = _BarcodeList.now(allBarcodes);
    await _put(getKey(productList), newList);
  }

  Future<ProductList> rename(
    final ProductList initialList,
    final String newName,
  ) async {
    final ProductList newList = ProductList.user(newName);
    final _BarcodeList list = await _get(initialList) ??
        _BarcodeList.now(<int, List<ScannedBarcode>>{});
    await _put(getKey(newList), list);
    await delete(initialList, rename: true);

    await ProductListFirebaseManager().renameProductList(
      productList: initialList,
      newName: newName,
    );

    await get(newList);
    return newList;
  }

  /// Exports a list - typically for debug purposes
  Future<Map<String, dynamic>> export(final ProductList productList) async {
    final Map<String, dynamic> result = <String, dynamic>{};
    final _BarcodeList? list = await _get(productList);
    if (list == null) {
      return result;
    }
    final DaoProduct daoProduct = DaoProduct(localDatabase);
    final List<String> allProductBarcodes = getAllBarcodes(list.barcodes);
    for (final String barcode in allProductBarcodes) {
      late bool? present;
      try {
        final Product? product = await daoProduct.get(barcode);
        present = product != null;
      } catch (e) {
        present = null;
      }
      result[barcode] = present;
    }
    return result;
  }

  /// Returns the names of the user lists.
  List<String> getUserLists() {
    final List<String> result = <String>[];
    for (final dynamic key in _getBox().keys) {
      final String tmp = key.toString();
      final ProductListType productListType = getProductListType(tmp);
      if (productListType != ProductListType.USER) {
        continue;
      }
      result.add(getProductListParameters(tmp));
    }
    return result;
  }

  /// Returns the names of the user lists that contains ALL the given barcodes.
  Future<List<String>> getUserListsWithBarcodes(
    final List<String> withBarcodes,
  ) async {
    final List<String> result = <String>[];
    for (final dynamic key in _getBox().keys) {
      final String tmp = key.toString();
      final ProductListType productListType = getProductListType(tmp);

      if (productListType != ProductListType.USER) {
        continue;
      }

      final _BarcodeList? barcodeList = await _getBox().get(key);
      if (barcodeList == null) {
        continue;
      }

      final List<String> allListScannedBarcodes =
          getAllBarcodes(barcodeList.barcodes);
      for (final String barcode in withBarcodes) {
        if (!allListScannedBarcodes.contains(barcode)) {
          break;
        }

        if (withBarcodes.last == barcode) {
          result.add(getProductListParameters(tmp));
          break;
        }
      }
    }
    return result;
  }

  /// Returns a write-safe copy of [_BarcodeList] barcodes.
  ///
  /// cf. https://github.com/openfoodfacts/smooth-app/issues/1786
  /// As we're using hive, all the data are loaded at init time. And not
  /// systematically refreshed at each [get] call.
  /// Therefore, when we need a barcode list from [_BarcodeList] with the intent
  /// to add/remove a barcode to/from that list, we can avoid concurrency issues
  /// by copying the barcode list instead of reusing it.
  /// Example:
  /// BAD
  /// ```dart
  /// List<String> barcodes = _barcodeList.barcodes;
  /// barcodes.add('1234'); // dangerous if somewhere else we parse the list
  /// ```
  /// GOOD
  /// ```dart
  /// List<String> barcodes = _getSafeBarcodeListCopy(_barcodeList.barcodes);
  /// barcodes.add('1234'); // no risk at all
  /// ```
  static Map<int, List<ScannedBarcode>> _getSafeBarcodeListCopy(
          final Map<int, List<ScannedBarcode>> barcodes) =>
      Map<int, List<ScannedBarcode>>.from(barcodes);
}
