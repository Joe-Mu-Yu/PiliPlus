import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/disabled_icon.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/search/search_rcmd/data.dart';
import 'package:PiliPlus/pages/home/view.dart' show msgBadge, userAvatar;
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search/widgets/hot_keyword.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/em.dart' show Em;
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _tag = Utils.generateRandomString(6);
  final _mainController = Get.putOrFind(MainController.new);
  late final SSearchController _searchController;
  late ThemeData theme;
  late bool isPortrait;
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    _searchController = Get.put(SSearchController(_tag), tag: _tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
    padding = MediaQuery.viewPaddingOf(context);
    isPortrait = MediaQuery.sizeOf(context).isPortrait;
  }

  @override
  Widget build(BuildContext context) {
    final trending = _searchController.enableTrending
        ? _buildHotSearch()
        : null;
    final rcmd = _searchController.enableSearchRcmd
        ? _buildHotSearch(isTrending: false)
        : null;

    // The content flows behind a floating glass search bar so the blur has
    // real pixels to sample; a plain opaque AppBar cannot show a gaussian
    // blur of anything.
    final appBarHeight = kToolbarHeight + padding.top;
    return Material(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: .only(left: padding.left, right: padding.right),
              child: ViewInsetsSafeArea(
                child: CustomScrollView(
                  slivers: [
                    // Reserve the bar's slot at the top, but let the list run
                    // underneath it while scrolling so the blur samples real
                    // content.
                    SliverPadding(padding: EdgeInsets.only(top: appBarHeight)),
                    if (_searchController.searchSuggestion)
                      _buildSearchSuggest(),
                    if (isPortrait) ...[
                      ?trending,
                      _buildHistory,
                      ?rcmd,
                    ] else if (trending != null || rcmd != null)
                      SliverCrossAxisGroup(
                        slivers: [
                          SliverMainAxisGroup(slivers: [?trending, ?rcmd]),
                          _buildHistory,
                        ],
                      )
                    else
                      _buildHistory,
                    SliverPadding(padding: .only(bottom: padding.bottom)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildGlassAppBar(appBarHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(double height) {
    final scheme = theme.colorScheme;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.82),
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, padding.top + 6, 10, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: Get.back,
                  ),
                  const SizedBox(width: 2),
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 4),
                  msgBadge(_mainController),
                  const SizedBox(width: 2),
                  userAvatar(
                    colorScheme: scheme,
                    mainController: _mainController,
                  ),
                  const SizedBox(width: 2),
                  Obx(
                    () => _searchController.showUidBtn.value
                        ? IconButton(
                            tooltip: 'UID搜索用户',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.person_outline, size: 22),
                            onPressed: () => Get.toNamed(
                              '/member?mid=${_searchController.controller.text}',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Single translucent capsule. The field itself draws no border of any
  /// state: the app-wide [InputDecorationTheme] supplies a primary-coloured
  /// focusedBorder, which used to appear as a stray blue ring inside the pill.
  Widget _buildSearchField() {
    const radius = BorderRadius.all(Radius.circular(18));
    final scheme = theme.colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            Icons.search_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              focusNode: _searchController.searchFocusNode,
              controller: _searchController.controller,
              textInputAction: TextInputAction.search,
              onChanged: _searchController.onChange,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
              cursorColor: scheme.primary,
              cursorHeight: 16,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: _searchController.hintText ?? '搜索',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (value) => _searchController.submit(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggest() {
    return Obx(() {
      final list = _searchController.searchSuggestList;
      return list.isNotEmpty &&
              list.first.term != null &&
              _searchController.controller.text != ''
          ? SliverList.list(
              children: list
                  .map(
                    (item) => InkWell(
                      borderRadius: const .all(.circular(4)),
                      onTap: () => _searchController.onClickKeyword(item.term!),
                      child: Padding(
                        padding: const .only(left: 20, top: 9, bottom: 9),
                        child: Text.rich(
                          TextSpan(
                            children: Em.regTitle(item.textRich)
                                .map(
                                  (e) => TextSpan(
                                    text: e.text,
                                    style: e.isEm
                                        ? TextStyle(
                                            fontWeight: .bold,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          : const SliverToBoxAdapter();
    });
  }

  Widget _buildHotSearch({
    bool isTrending = true,
  }) {
    final text = Text(
      isTrending ? '大家都在搜' : '搜索发现',
      strutStyle: const StrutStyle(leading: 0, height: 1),
      style: theme.textTheme.titleMedium!.copyWith(
        height: 1,
        fontWeight: .bold,
      ),
    );
    final outline = theme.colorScheme.outline;
    final secondary = theme.colorScheme.secondary;
    final style = TextStyle(
      height: 1,
      fontSize: 13,
      color: outline,
    );
    return SliverPadding(
      padding: .fromLTRB(
        10,
        !isTrending && (isPortrait || _searchController.enableTrending)
            ? 4
            : 25,
        4,
        25,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const .fromLTRB(6, 0, 6, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  isTrending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            text,
                            const SizedBox(width: 14),
                            TextButton(
                              style: const ButtonStyle(
                                visualDensity: .compact,
                                tapTargetSize: .shrinkWrap,
                                padding: WidgetStatePropertyAll(
                                  .symmetric(horizontal: 10),
                                ),
                              ),
                              onPressed: () => Get.toNamed('/searchTrending'),
                              child: Row(
                                children: [
                                  Text(
                                    '完整榜单',
                                    strutStyle: const StrutStyle(
                                      leading: 0,
                                      height: 1,
                                    ),
                                    style: style,
                                  ),
                                  Icon(
                                    size: 18,
                                    Icons.keyboard_arrow_right,
                                    color: outline,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : text,
                  TextButton.icon(
                    style: const ButtonStyle(
                      visualDensity: .compact,
                      tapTargetSize: .shrinkWrap,
                      padding: WidgetStatePropertyAll(
                        .symmetric(horizontal: 10),
                      ),
                    ),
                    onPressed: isTrending
                        ? _searchController.queryTrendingList
                        : _searchController.queryRecommendList,
                    icon: Icon(
                      Icons.refresh_outlined,
                      size: 18,
                      color: secondary,
                    ),
                    label: Text(
                      '刷新',
                      strutStyle: const StrutStyle(leading: 0, height: 1),
                      style: TextStyle(height: 1, color: secondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(
            () => _buildHotKey(
              isTrending
                  ? _searchController.trendingState.value
                  : _searchController.recommendData.value,
              isTrending,
            ),
          ),
        ],
      ),
    );
  }

  late final mainAxisExtent = 16 + MediaQuery.textScalerOf(context).scale(14);
  Widget get _buildHistory {
    return Obx(
      () {
        final list = _searchController.historyList;
        if (list.isEmpty) {
          return const SliverToBoxAdapter();
        }
        final secondary = theme.colorScheme.secondary;
        return SliverPadding(
          padding: .fromLTRB(
            10,
            !isPortrait
                ? 25
                : _searchController.enableTrending
                ? 0
                : 6,
            6,
            25,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: const .fromLTRB(6, 0, 6, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        '搜索历史',
                        strutStyle: const StrutStyle(leading: 0, height: 1),
                        style: theme.textTheme.titleMedium!.copyWith(
                          height: 1,
                          fontWeight: .bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _recordBtn,
                      _exportBtn,
                      const Spacer(),
                      TextButton.icon(
                        style: const ButtonStyle(
                          visualDensity: .compact,
                          tapTargetSize: .shrinkWrap,
                          padding: WidgetStatePropertyAll(
                            .symmetric(horizontal: 10),
                          ),
                        ),
                        onPressed: _searchController.onClearHistory,
                        icon: Icon(
                          Icons.clear_all_outlined,
                          size: 18,
                          color: secondary,
                        ),
                        label: Text(
                          '清空',
                          style: TextStyle(height: 1, color: secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverFixedWrap(
                mainAxisExtent: mainAxisExtent,
                spacing: 8,
                runSpacing: 8,
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  childCount: list.length,
                  (context, index) => SearchText(
                    text: list[index],
                    onTap: _searchController.onClickKeyword,
                    onLongPress: _searchController.onLongSelect,
                    fontSize: 14,
                    height: 1,
                    padding: const .fromLTRB(11, 8, 11, 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget get _recordBtn => Obx(
    () {
      bool enable = _searchController.recordSearchHistory.value;
      return IconButton(
        iconSize: 22,
        tooltip: enable ? '记录搜索' : '无痕搜索',
        icon: DisabledIcon(
          disable: !enable,
          child: Icon(
            Icons.history,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        style: const ButtonStyle(
          visualDensity: .comfortable,
          tapTargetSize: .shrinkWrap,
          padding: WidgetStatePropertyAll(.zero),
        ),
        onPressed: () {
          enable = !enable;
          _searchController.recordSearchHistory.value = enable;
          GStorage.setting.put(
            SettingBoxKey.recordSearchHistory,
            enable,
          );
        },
      );
    },
  );

  Widget get _exportBtn => IconButton(
    iconSize: 22,
    tooltip: '导入/导出历史记录',
    icon: Icon(
      Icons.import_export_outlined,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    ),
    style: const ButtonStyle(
      visualDensity: .comfortable,
      tapTargetSize: .shrinkWrap,
      padding: WidgetStatePropertyAll(.zero),
    ),
    onPressed: () => showImportExportDialog<List>(
      context,
      title: '历史记录',
      localFileName: () => 'search',
      onExport: () => jsonEncode(_searchController.historyList),
      onImport: (json) {
        final list = List<String>.from(json);
        _searchController.historyList.value = list;
        GStorage.historyWord.put('cacheList', list);
      },
    ),
  );

  Widget _buildHotKey(
    LoadingState<SearchRcmdData> loadingState,
    bool isTrending,
  ) {
    return switch (loadingState) {
      Success(:final response) when (response.list?.isNotEmpty ?? false) =>
        SliverHotKeyword(
          hotSearchList: response.list!,
          onClick: _searchController.onClickKeyword,
        ),
      Error(:final errMsg) => HttpError(
        safeArea: false,
        errMsg: errMsg,
        onReload: isTrending
            ? _searchController.queryTrendingList
            : _searchController.queryRecommendList,
      ),
      _ => const SliverToBoxAdapter(),
    };
  }
}
