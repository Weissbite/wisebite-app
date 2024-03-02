import 'package:intl/intl.dart';
import 'package:smooth_app/database/dao_product_list.dart';

int getTodayDateAsScannedBarcodeKey() =>
    parseDateTimeAsScannedBarcodeKey(DateTime.now());

int parseDateTimeAsScannedBarcodeKey(final DateTime date) =>
    int.parse(DateFormat('yyMMdd').format(date));

List<String> getAllBarcodes(final Map<int, List<ScannedBarcode>> barcodes,
    [final bool newFirst = true]) {
  final List<String> allBarcodes = <String>[];
  for (final List<ScannedBarcode> i in barcodes.values) {
    for (final ScannedBarcode j in i) {
      allBarcodes.add(j.barcode);
    }
  }

  if (newFirst) {
    return allBarcodes.reversed.toList();
  }

  return allBarcodes;
}

// Searches for a barcode inside the given map of scanned barcodes
// Returns true if the barcode is found inside the given map and false otherwise
// It can manipulate the found barcode and it's list, if any found
bool barcodeExists(
  Map<int, List<ScannedBarcode>> barcodes,
  final String barcode, [
  final void Function(ScannedBarcode, List<ScannedBarcode>, int)?
      doSomethingWithFoundValue,
]) {
  for (final MapEntry<int, List<ScannedBarcode>> entry in barcodes.entries) {
    for (final ScannedBarcode j in entry.value) {
      if (j.barcode == barcode) {
        if (doSomethingWithFoundValue != null) {
          doSomethingWithFoundValue(j, entry.value, entry.key);
        }

        return true;
      }
    }
  }

  return false;
}
