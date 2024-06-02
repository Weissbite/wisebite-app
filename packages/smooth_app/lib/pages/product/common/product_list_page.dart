import 'dart:collection';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/data_models/product_list.dart';
import 'package:smooth_app/data_models/up_to_date_product_list_mixin.dart';
import 'package:smooth_app/data_models/user_management_provider.dart';
import 'package:smooth_app/database/dao_product.dart';
import 'package:smooth_app/database/dao_product_list.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/database/scanned_barcodes_manager.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/generic_lib/duration_constants.dart';
import 'package:smooth_app/generic_lib/loading_dialog.dart';
import 'package:smooth_app/helpers/app_helper.dart';
import 'package:smooth_app/helpers/robotoff_insight_helper.dart';
import 'package:smooth_app/pages/carousel_manager.dart';
import 'package:smooth_app/pages/preferences/user_preferences_dev_mode.dart';
import 'package:smooth_app/pages/product/common/product_list_item_popup_items.dart';
import 'package:smooth_app/pages/product/common/product_list_item_simple.dart';
import 'package:smooth_app/pages/product/common/product_refresher.dart';
import 'package:smooth_app/query/product_query.dart';
import 'package:smooth_app/widgets/smooth_app_bar.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';
import 'package:smooth_app/widgets/will_pop_scope.dart';

extension _DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return day == other.day && month == other.month && year == other.year;
  }
}

/// Displays the products of a product list, with access to other lists.
class ProductListPage extends StatefulWidget {
  const ProductListPage(
    this.productList, {
    this.allowToSwitchBetweenLists = true,
  });

  final ProductList productList;
  final bool allowToSwitchBetweenLists;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with TraceableClientMixin, UpToDateProductListMixin {
  final Set<ScannedBarcode> _selectedBarcodes = <ScannedBarcode>{};
  bool _selectionMode = false;

  @override
  String get actionName => 'Opened list_page';

  @override
  void initState() {
    super.initState();
    initUpToDate(widget.productList, context.read<LocalDatabase>());
    _fetchDaysWithProducts();
  }

  final ProductListItemPopupItem _deleteItems = ProductListItemPopupDelete();
  final ProductListItemPopupItem _rankItems = ProductListItemPopupRank();
  final ProductListItemPopupItem _sideBySideItems =
      ProductListItemPopupSideBySide();

  final CarouselController _controller = CarouselController();
  bool _hideLeftArrow = false;

  DateTime _selectedDate = DateTime.now();

  /// List of days with products for the current product list
  List<int> _daysWithProducts = <int>[];

  /// Handles the right left tap
  void _navigateToPreviousDay() {
    _controller.nextPage();
  }

  /// Handles the right arrow tap
  void _navigateToNextDay() {
    _controller.previousPage();
  }

  /// Returns true if the given date is today, otherwise returns false
  bool _isDateToday(final DateTime date) => date.isSameDate(DateTime.now());

  /// Formats the currently selected date to text
  String _getSelectedDayText() {
    final DateTime now = DateTime.now();
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (_isDateToday(_selectedDate)) {
      return 'Today';
    } else if (_selectedDate.isSameDate(yesterday)) {
      return 'Yesterday';
    } else if (_selectedDate.isSameDate(tomorrow)) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    }
  }

  /// returns bool to handle WillPopScope
  Future<bool> _handleUserBacktap() async {
    if (_selectionMode) {
      setState(
        () {
          _selectionMode = false;
          _selectedBarcodes.clear();
        },
      );
    }

    return false;
  }

  /// Shows a calendar and handles the date selection
  /// If a user's logged in the first allowed date is the day of the user creation
  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final ThemeData themeData = Theme.of(context);
    final bool userIsLoggedIn = UserManagementProvider.user != null;

    final DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: userIsLoggedIn
            ? UserManagementProvider.user!.metadata.creationTime!
            : DateTime(now.year - 1, now.month, now.day),
        lastDate: now,
        selectableDayPredicate: (final DateTime date) =>
            _daysWithProducts.contains(parseDateTimeAsScannedBarcodeKey(date)),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary:
                    themeData.colorScheme.surface, // header background color
                onPrimary: themeData.colorScheme.onSurface, // header text color
                onSurface: themeData.primaryColor, // calendar dates color
              ),
            ),
            child: child!,
          );
        });

    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
      });

      final int indexOfSelectedDay = _daysWithProducts
          .indexOf(parseDateTimeAsScannedBarcodeKey(_selectedDate));
      _controller.animateToPage(indexOfSelectedDay);
    }
  }

  /// Fetches and sorts the days with products for the product list
  void _fetchDaysWithProducts() {
    _daysWithProducts.clear();

    final ScannedBarcodesMap barcodes = productList.getList();

    barcodes.forEach((int key, LinkedHashSet<ScannedBarcode> value) {
      if (value.isNotEmpty) {
        _daysWithProducts.add(key);
      }
    });

    _daysWithProducts.sort();
    _daysWithProducts = _daysWithProducts.reversed.toList();

    /// Today's date should be always in the list, even if there are no scanned products for it
    final int todayAsKey = getTodayDateAsScannedBarcodeKey();
    if (!_daysWithProducts.contains(todayAsKey)) {
      _daysWithProducts.insert(0, todayAsKey);
    }
  }

  void _onDateChange(final int index) {
    final int newDate = _daysWithProducts[index];

    // Create a DateTime object from the key
    final String keyString = newDate.toString()..padLeft(6, '0');
    final String formattedDate =
        '20${keyString.substring(0, 2)}-${keyString.substring(2, 4)}-${keyString.substring(4, 6)}';

    setState(() {
      _selectedDate = DateTime.parse(formattedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final LocalDatabase localDatabase = context.watch<LocalDatabase>();
    final ThemeData themeData = Theme.of(context);
    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    final UserPreferences userPreferences = context.watch<UserPreferences>();
    refreshUpToDate();
    _fetchDaysWithProducts();

    final bool loadingFromFirebase = localDatabase.loadingFromFirebase;

    // Determine if the selected date is the earliest date with scanned products
    final int indexOfSelectedDay = _daysWithProducts
        .indexOf(parseDateTimeAsScannedBarcodeKey(_selectedDate));
    _hideLeftArrow = _daysWithProducts.length == (indexOfSelectedDay + 1);

    return SmoothScaffold(
      floatingActionButton: _isDateToday(_selectedDate)
          ? FloatingActionButton.extended(
              icon: const Icon(CupertinoIcons.barcode),
              label: Text(appLocalizations.product_list_empty_title),
              onPressed: () =>
                  ExternalCarouselManager.read(context).showSearchCard(),
            )
          : null,
      appBar: SmoothAppBar(
        leading: loadingFromFirebase
            ? const Padding(
                padding: EdgeInsets.all(MEDIUM_SPACE),
                child: CircularProgressIndicator.adaptive(),
              )
            : _hideLeftArrow || _daysWithProducts.length <= 1
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: _navigateToPreviousDay,
                  ),
        title: ElevatedButton(
            child: Text(
              _getSelectedDayText(),
              style: const TextStyle(fontSize: 18.0),
            ),
            onPressed: () => _selectDate()),
        centerTitle: true,
        // Buttons at the end of the AppBar
        actions: <Widget>[
          if (!_isDateToday(_selectedDate))
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: _navigateToNextDay,
            ),
        ],
        actionMode: _selectionMode,
        onLeaveActionMode: () {
          setState(() => _selectionMode = false);
        },
        actionModeTitle: Text('${_selectedBarcodes.length}'),
        actionModeActions: <Widget>[
          PopupMenuButton<ProductListItemPopupItem>(
            onSelected: (final ProductListItemPopupItem action) async {
              final bool andThenSetState = await action.doSomething(
                productList: productList,
                localDatabase: localDatabase,
                context: context,
                selectedBarcodes: _selectedBarcodes,
              );
              if (andThenSetState) {
                if (context.mounted) {
                  setState(() {
                    if (action.isDelete) {
                      _selectionMode = false;
                      _selectedBarcodes.clear();
                      _navigateToNextDay();
                    }
                  });
                }
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<ProductListItemPopupItem>>[
              if (userPreferences.getFlag(UserPreferencesDevMode
                      .userPreferencesFlagBoostedComparison) ==
                  true)
                _sideBySideItems.getMenuItem(
                  appLocalizations,
                  _selectedBarcodes.length >= 2 &&
                      _selectedBarcodes.length <= 3,
                ),
              _rankItems.getMenuItem(
                appLocalizations,
                _selectedBarcodes.length >= 2,
              ),
              _deleteItems.getMenuItem(
                appLocalizations,
                _selectedBarcodes.isNotEmpty,
              ),
            ],
          ),
        ],
      ),
      body: CarouselSlider.builder(
        itemCount: _daysWithProducts.length,
        itemBuilder: (BuildContext context, int itemIndex, int pageViewIndex) {
          final int selectedDay = _daysWithProducts[itemIndex];
          final LinkedHashSet<ScannedBarcode>? selectedDayBarcodes =
              productList.getList()[selectedDay];

          return selectedDayBarcodes == null || selectedDayBarcodes.isEmpty
              ? LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      RefreshIndicator(
                        //if it is in selectmode then refresh indicator is not shown
                        notificationPredicate:
                            _selectionMode ? (_) => false : (_) => true,
                        onRefresh: () async => _refreshListProducts(
                          getAllBarcodes(productList.getList()),
                          localDatabase,
                          appLocalizations,
                        ),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(SMALL_SPACE),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: <Widget>[
                                    SvgPicture.asset(
                                      'assets/misc/empty-list.svg',
                                      package: AppHelper.APP_PACKAGE,
                                      width:
                                          MediaQuery.of(context).size.width / 2,
                                    ),
                                    Text(
                                      appLocalizations
                                          .product_list_empty_message,
                                      textAlign: TextAlign.center,
                                      style:
                                          themeData.textTheme.bodyMedium?.apply(
                                        color:
                                            themeData.colorScheme.onBackground,
                                      ),
                                    ),
                                    EMPTY_WIDGET,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ))
              : WillPopScope2(
                  onWillPop: () async => (await _handleUserBacktap(), null),
                  child: RefreshIndicator(
                      //if it is in selectmode then refresh indicator is not shown
                      notificationPredicate:
                          _selectionMode ? (_) => false : (_) => true,
                      onRefresh: () async => _refreshListProducts(
                            getAllBarcodes(productList.getList()),
                            localDatabase,
                            appLocalizations,
                          ),
                      child: ListView.builder(
                        itemCount: selectedDayBarcodes.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _buildItem(
                          selectedDayBarcodes
                              .toList()
                              .reversed
                              .toList(), // Reverse the list so that the most recently scanned barcodes are at the top
                          index,
                          localDatabase,
                          appLocalizations,
                        ),
                      )),
                );
        },
        options: CarouselOptions(
            height: MediaQuery.of(context).size.height,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            enableInfiniteScroll: false,
            reverse: true,
            onPageChanged: (final int index, _) => _onDateChange(index)),
        carouselController: _controller,
      ),
    );
  }

  Widget _buildItem(
    final List<ScannedBarcode> barcodes,
    final int index,
    final LocalDatabase localDatabase,
    final AppLocalizations appLocalizations,
  ) {
    final ScannedBarcode barcode = barcodes.elementAt(index);
    final bool selected = _selectedBarcodes.contains(barcode);
    void onTap() => setState(
          () {
            if (selected) {
              _selectedBarcodes.remove(barcode);
            } else {
              _selectedBarcodes.add(barcode);
            }
          },
        );
    final Widget child = InkWell(
      onTap: _selectionMode ? onTap : null,
      child: Container(
        padding: EdgeInsetsDirectional.only(
          start: _selectionMode ? SMALL_SPACE : 0,
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:
                  _selectionMode ? (IconTheme.of(context).size ?? 20.0) : 0.0,
              child: Offstage(
                offstage: !_selectionMode,
                child: Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                ),
              ),
            ),
            Expanded(
              child: ProductListItemSimple(
                barcode: barcode.barcode,
                onTap: _selectionMode ? onTap : null,
                onLongPress: !_selectionMode
                    ? () => setState(
                          () {
                            _selectedBarcodes.add(barcode);
                            _selectionMode = true;
                          },
                        )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      key: Key(barcode.barcode),
      child: child,
    );
  }

  /// Calls the "refresh products" part with dialogs on top.
  Future<void> _refreshListProducts(
    final List<String> products,
    final LocalDatabase localDatabase,
    final AppLocalizations appLocalizations,
  ) async {
    final bool? done = await LoadingDialog.run<bool>(
      context: context,
      title: appLocalizations.product_list_reloading_in_progress_multiple(
        products.length,
      ),
      future: _reloadProducts(products, localDatabase),
    );
    switch (done) {
      case null: // user clicked on "stop"
        return;
      case true:
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appLocalizations.product_list_reloading_success_multiple(
                products.length,
              ),
            ),
            duration: SnackBarDuration.short,
          ),
        );
        setState(() {});
        return;
      case false:
        if (context.mounted) {
          LoadingDialog.error(context: context);
        }
        return;
    }
  }

  /// Fetches the products from the API and refreshes the local database
  Future<bool> _reloadProducts(
    final List<String> barcodes,
    final LocalDatabase localDatabase,
  ) async {
    try {
      final OpenFoodFactsLanguage language = ProductQuery.getLanguage();
      final SearchResult searchResult = await OpenFoodAPIClient.searchProducts(
        ProductQuery.getUser(),
        ProductRefresher().getBarcodeListQueryConfiguration(
          barcodes,
          language,
        ),
        uriHelper: ProductQuery.uriProductHelper,
      );
      final List<Product>? freshProducts = searchResult.products;
      if (freshProducts == null) {
        return false;
      }
      await DaoProduct(localDatabase).putAll(freshProducts, language);
      localDatabase.upToDate.setLatestDownloadedProducts(freshProducts);
      final RobotoffInsightHelper robotoffInsightHelper =
          RobotoffInsightHelper(localDatabase);
      await robotoffInsightHelper.clearInsightAnnotationsSaved();
      return true;
    } catch (e) {
      //
    }
    return false;
  }
}
