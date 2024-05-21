import 'dart:collection';

import 'package:intl/intl.dart';
import 'package:smooth_app/database/dao_product_list.dart';

int getTodayDateAsScannedBarcodeKey() =>
    parseDateTimeAsScannedBarcodeKey(DateTime.now());

int parseDateTimeAsScannedBarcodeKey(final DateTime date) =>
    int.parse(DateFormat('yyMMdd').format(date));

List<String> getAllBarcodes(
  final ScannedBarcodesMap barcodes, [
  final bool newFirst = true,
]) {
  final List<String> allBarcodes = <String>[];
  for (final LinkedHashSet<ScannedBarcode> i in barcodes.values) {
    for (final ScannedBarcode element in i) {
      allBarcodes.add(element.barcode);
    }
  }

  if (newFirst) {
    return allBarcodes.reversed.toList();
  }

  return allBarcodes;
}

int getNumberOfAllBarcodes(final ScannedBarcodesMap barcodes) {
  int numberOfBarcodes = 0;
  for (final LinkedHashSet<ScannedBarcode> i in barcodes.values) {
    numberOfBarcodes += i.length;
  }

  return numberOfBarcodes;
}

int getScanTimeDifferenceInSeconds({
  required final int oldScanTime,
  required final int newScanTime,
}) {
  final DateTime oldBarcodeScanTime =
      DateTime.fromMillisecondsSinceEpoch(oldScanTime);
  final DateTime newBarcodeScanTime =
      DateTime.fromMillisecondsSinceEpoch(newScanTime);

  return newBarcodeScanTime.difference(oldBarcodeScanTime).inSeconds;
}
