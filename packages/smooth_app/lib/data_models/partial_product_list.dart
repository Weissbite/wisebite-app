import 'package:smooth_app/data_models/product_list.dart';

/// List of [Product]s out of partial results (e.g. paged results).
class PartialProductList {
  final Map<int, List<String>> _barcodes = <int, List<String>>{};
  int _totalSize = 0;

  /// Total size of the list from which this partial list is taken.
  int get totalSize => _totalSize;

  Map<int, List<String>> getBarcodes() => _barcodes;

  void add(final ProductList productList) {
    _barcodes.addAll(productList.getList());
    _totalSize = productList.totalSize;
  }

  void clear() {
    _barcodes.clear();
    _totalSize = 0;
  }
}
