import 'dart:collection';

import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/database/dao_product_list.dart';

/// List of [Product]s out of partial results (e.g. paged results).
class PartialProductList {
  final ScannedBarcodesMap _barcodes = <int, LinkedHashSet<ScannedBarcode>>{};
  int _totalSize = 0;

  /// Total size of the list from which this partial list is taken.
  int get totalSize => _totalSize;

  ScannedBarcodesMap getBarcodes() => _barcodes;

  void add(final ProductList productList) {
    _barcodes.addAll(productList.getList());
    _totalSize = productList.totalSize;
  }

  void clear() {
    _barcodes.clear();
    _totalSize = 0;
  }
}
