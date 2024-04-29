import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/fetched_product.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/database/dao_product.dart';
import 'package:smooth_app/database/dao_product_list.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/database/scanned_barcodes_manager.dart';
import 'package:smooth_app/generic_lib/duration_constants.dart';
import 'package:smooth_app/helpers/analytics_helper.dart';
import 'package:smooth_app/helpers/collections_helper.dart';
import 'package:smooth_app/query/barcode_product_query.dart';
import 'package:smooth_app/services/smooth_services.dart';

enum ScannedProductState {
  FOUND,
  NOT_FOUND,
  LOADING,
  THANKS,
  CACHED,
  ERROR_INTERNET,
  ERROR_INVALID_CODE,
}

class ContinuousScanModel with ChangeNotifier {
  ContinuousScanModel();

  final Map<String, ScannedProductState> _states =
      <String, ScannedProductState>{};
  final Map<int, LinkedHashSet<ScannedBarcode>> _barcodes =
      <int, LinkedHashSet<ScannedBarcode>>{};
  final ProductList _productList = ProductList.scanSession();
  final ProductList _history = ProductList.history();
  final ProductList _scanHistory = ProductList.scanHistory();

  ScannedBarcode? _latestScannedBarcode;
  ScannedBarcode? _latestFoundBarcode;
  ScannedBarcode? _latestConsultedBarcode;
  late DaoProduct _daoProduct;
  late DaoProductList _daoProductList;

  ProductList get productList => _productList;

  /// List all barcodes scanned (even products being loaded or not found)
  Map<int, LinkedHashSet<ScannedBarcode>> getBarcodes() => _barcodes;

  /// List only barcodes where the product exists
  Iterable<String> getAvailableBarcodes() => _states
      .where((MapEntry<String, ScannedProductState> entry) =>
          entry.value == ScannedProductState.FOUND ||
          entry.value == ScannedProductState.CACHED)
      .keys;

  ScannedBarcode? get latestConsultedBarcode => _latestConsultedBarcode;

  set lastConsultedBarcode(ScannedBarcode? barcode) {
    _latestConsultedBarcode = barcode;
    if (barcode != null) {
      notifyListeners();
    }
  }

  Future<ContinuousScanModel?> load(final LocalDatabase localDatabase) async {
    try {
      _daoProduct = DaoProduct(localDatabase);
      _daoProductList = DaoProductList(localDatabase);

      if (!await _refresh()) {
        return null;
      }
      return this;
    } catch (e) {
      Logs.e('Load database error', ex: e);
    }
    return null;
  }

  Future<bool> _refresh() async {
    try {
      _latestScannedBarcode = null;
      _latestFoundBarcode = null;
      _barcodes.clear();
      _states.clear();
      await refreshProductList();

      _productList.barcodes
          .forEach((int key, LinkedHashSet<ScannedBarcode> value) {
        _barcodes[key] = value;
        for (final ScannedBarcode i in value) {
          _states[i.barcode] = ScannedProductState.CACHED;
          _latestScannedBarcode = i;
        }
      });

      return true;
    } catch (e) {
      Logs.e('Refresh database error', ex: e);
    }
    return false;
  }

  Future<void> refreshProductList() async => _daoProductList.get(_productList);

  void _setBarcodeState(
    final String barcode,
    final ScannedProductState state,
  ) {
    _states[barcode] = state;
    notifyListeners();
  }

  ScannedProductState? getBarcodeState(final String barcode) =>
      _states[barcode];

  /// Adds a barcode
  /// Will return [true] if this barcode is successfully added
  Future<bool> onScan(String? code) async {
    if (code == null) {
      return false;
    }

    code = _fixBarcodeIfNecessary(code);

    AnalyticsHelper.trackEvent(
      AnalyticsEvent.scanAction,
      barcode: code,
    );

    return _addBarcode(ScannedBarcode(code));
  }

  Future<bool> onCreateProduct(String? barcode) async {
    if (barcode == null) {
      return false;
    }
    return _addBarcode(ScannedBarcode(barcode));
  }

  Future<void> retryBarcodeFetch(String barcode) async {
    _setBarcodeState(barcode, ScannedProductState.LOADING);
    await _updateBarcode(barcode);
  }

  Future<bool> _addBarcode(final ScannedBarcode barcode) async {
    final int todayAsKey = getTodayDateAsScannedBarcodeKey();
    _barcodes[todayAsKey] ??= LinkedHashSet<ScannedBarcode>();
    final LinkedHashSet<ScannedBarcode> todayScannedBarcodes =
        _barcodes[todayAsKey]!;

    // Don't add the same barcode to the list if it was scanned less than a minute ago.
    // Sometimes when scanning, the scanner sends multiple requests for a new scan of the same product.
    // We want to prevent multiple items of the same barcode being added at once.
    if (todayScannedBarcodes.isNotEmpty &&
        _latestScannedBarcode != null &&
        _latestScannedBarcode!.barcode == barcode.barcode &&
        getScanTimeDifferenceInSeconds(
              oldScanTime: _latestScannedBarcode!.lastScanTime,
              newScanTime: barcode.lastScanTime,
            ) <=
            60) {
      return true;
    }

    _latestScannedBarcode = barcode;
    _barcodes[todayAsKey]!.add(barcode);

    final ScannedProductState? state = getBarcodeState(barcode.barcode);
    if (state == null || state == ScannedProductState.NOT_FOUND) {
      _setBarcodeState(barcode.barcode, ScannedProductState.LOADING);
      _cacheOrLoadBarcode(barcode.barcode);
      lastConsultedBarcode = barcode;

      return true;
    }

    if (state == ScannedProductState.FOUND ||
        state == ScannedProductState.CACHED) {
      await _addProduct(barcode, state);

      if (state == ScannedProductState.CACHED) {
        await _updateBarcode(barcode.barcode);
      }

      lastConsultedBarcode = barcode;

      return true;
    }

    return false;
  }

  Future<void> _cacheOrLoadBarcode(final String barcode) async {
    final bool cached = await _cachedBarcode(barcode);
    if (!cached) {
      _loadBarcode(barcode);
    }
  }

  Future<bool> _cachedBarcode(final String barcode) async {
    final Product? product = await _daoProduct.get(barcode);
    if (product != null) {
      try {
        // We try to load the fresh copy of product from the server
        final FetchedProduct fetchedProduct =
            await _queryBarcode(barcode).timeout(SnackBarDuration.long);
        if (fetchedProduct.product != null) {
          _addProduct(ScannedBarcode(barcode), ScannedProductState.CACHED);
          return true;
        }
      } on TimeoutException {
        // We tried to load the product from the server,
        // but it was taking more than 5 seconds.
        // So we'll just show the already cached product.
        _addProduct(ScannedBarcode(barcode), ScannedProductState.CACHED);
        return true;
      }
      _addProduct(ScannedBarcode(barcode), ScannedProductState.CACHED);
      return true;
    }
    return false;
  }

  Future<FetchedProduct> _queryBarcode(
    final String barcode,
  ) async =>
      BarcodeProductQuery(
        barcode: barcode,
        daoProduct: _daoProduct,
        isScanned: true,
      ).getFetchedProduct();

  Future<void> _loadBarcode(
    final String barcode,
  ) async {
    final FetchedProduct fetchedProduct = await _queryBarcode(barcode);
    switch (fetchedProduct.status) {
      case FetchedProductStatus.ok:
        _addProduct(ScannedBarcode(barcode), ScannedProductState.FOUND);
        return;
      case FetchedProductStatus.internetNotFound:
        _setBarcodeState(barcode, ScannedProductState.NOT_FOUND);
        return;
      case FetchedProductStatus.internetError:
        _setBarcodeState(barcode, ScannedProductState.ERROR_INTERNET);
        return;
      case FetchedProductStatus.userCancelled:
        // we do nothing
        return;
    }
  }

  Future<void> _updateBarcode(
    final String barcode,
  ) async {
    final FetchedProduct fetchedProduct = await _queryBarcode(barcode);
    switch (fetchedProduct.status) {
      case FetchedProductStatus.ok:
        _setBarcodeState(barcode, ScannedProductState.FOUND);
        return;
      case FetchedProductStatus.internetNotFound:
        _setBarcodeState(barcode, ScannedProductState.NOT_FOUND);
        return;
      case FetchedProductStatus.internetError:
        _setBarcodeState(barcode, ScannedProductState.ERROR_INTERNET);
        return;
      case FetchedProductStatus.userCancelled:
        // we do nothing
        return;
    }
  }

  Future<void> _addProduct(
    final ScannedBarcode barcode,
    final ScannedProductState state,
  ) async {
    if (_latestFoundBarcode != barcode) {
      _latestFoundBarcode = barcode;

      // await _daoProductList.push(productList, _latestFoundBarcode!);
      await _daoProductList.push(_scanHistory, _latestFoundBarcode!);
      await _daoProductList.push(_history, _latestFoundBarcode!);
      _daoProductList.localDatabase.notifyListeners();
    }
    _setBarcodeState(barcode.barcode, state);
  }

  Future<void> clearScanSession() async {
    await _daoProductList.clear(productList);
    await refresh();
  }

  Future<void> removeBarcode(
    final ScannedBarcode barcode,
  ) async {
    await _daoProductList.set(
      productList,
      barcode,
      false,
    );

    for (final LinkedHashSet<ScannedBarcode> i in _barcodes.values) {
      if (i.remove(barcode)) {
        break;
      }
    }

    _states.remove(barcode.barcode);

    if (_latestScannedBarcode != null && _latestScannedBarcode! == barcode) {
      _latestScannedBarcode = null;
    }

    notifyListeners();
  }

  Future<void> refresh() async {
    await _refresh();
    notifyListeners();
  }

  /// Sometimes the scanner may fail, this is a simple fix for now
  /// But could be improved in the future
  String _fixBarcodeIfNecessary(String code) {
    if (code.length == 12) {
      return '0$code';
    } else {
      return code;
    }
  }

  /// Whether we can show the user an interface to compare products
  /// BUT it doesn't necessary we can't compare yet.
  /// Please refer instead to [compareFeatureAvailable]
  bool get compareFeatureEnabled => getAvailableBarcodes().isNotEmpty;

  /// If we can compare products
  /// (= meaning we have at least two existing products)
  bool get compareFeatureAvailable => getAvailableBarcodes().length >= 2;
}
