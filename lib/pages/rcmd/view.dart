import 'dart:async';

import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());
  int _featuredIndex = 0;
  final ValueNotifier<double> _parallaxOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _parallaxOffset.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    final reduceMotion = ImmersiveTokens.reduceMotionOf(context);
    final pageBackground = colorScheme.brightness == Brightness.dark
        ? const Color(0xFF121212)
        : colorScheme.surface;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final bannerImageHeight = width * 9 / 16;
    final heroExtent = bannerImageHeight + 92.0;
    const fadeHeight = 100.0;

    return Obx(() {
      final state = controller.loadingState.value;
      final featured = controller.featuredItems;
      final selectedIndex = _featuredIndex.clamp(
        0,
        featured.isEmpty ? 0 : featured.length - 1,
      );
      return refreshIndicator(
        onRefresh: controller.onRefresh,
        child: ColoredBox(
          color: pageBackground,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 &&
                  notification is ScrollUpdateNotification) {
                final scrollY = notification.metrics.pixels;
                final travel = reduceMotion || scrollY < 0
                    ? 0.0
                    : -scrollY.clamp(0.0, heroExtent) * .4;
                if (_parallaxOffset.value != travel) {
                  _parallaxOffset.value = travel;
                }
              }
              return false;
            },
            child: CustomScrollView(
              controller: controller.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state case Success())
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: heroExtent,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (featured.isNotEmpty) ...[
                            Positioned.fill(
                              child: ValueListenableBuilder<double>(
                                valueListenable: _parallaxOffset,
                                builder: (context, offset, child) =>
                                    Transform.translate(
                                      offset: Offset(0, offset),
                                      child: child,
                                    ),
                                child: SizedBox(
                                  height: heroExtent,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                            ImmersiveTokens.contentChangeDuration(
                                              context,
                                            ),
                                        switchInCurve:
                                            ImmersiveTokens.settleCurve,
                                        switchOutCurve:
                                            ImmersiveTokens.contentCurve,
                                        transitionBuilder: (child, animation) {
                                          if (reduceMotion) return child;
                                          final opacity = CurvedAnimation(
                                            parent: animation,
                                            curve: ImmersiveTokens.contentCurve,
                                          );
                                          return FadeTransition(
                                            opacity: opacity,
                                            child: ScaleTransition(
                                              scale: Tween<double>(
                                                begin: .97,
                                                end: 1,
                                              ).animate(opacity),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: NetworkImgLayer(
                                          key: ValueKey(
                                            featured[selectedIndex].cover,
                                          ),
                                          src: featured[selectedIndex].cover,
                                          width: width,
                                          height: heroExtent,
                                          borderRadius: BorderRadius.zero,
                                          quality: 75,
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: fadeHeight,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  pageBackground.withValues(
                                                    alpha: 0,
                                                  ),
                                                  pageBackground.withValues(
                                                    alpha: .015,
                                                  ),
                                                  pageBackground.withValues(
                                                    alpha: .06,
                                                  ),
                                                  pageBackground.withValues(
                                                    alpha: .18,
                                                  ),
                                                  pageBackground.withValues(
                                                    alpha: .42,
                                                  ),
                                                  pageBackground.withValues(
                                                    alpha: .72,
                                                  ),
                                                  pageBackground,
                                                ],
                                                stops: const [
                                                  0,
                                                  .16,
                                                  .32,
                                                  .52,
                                                  .72,
                                                  .9,
                                                  1,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            RecommendationFeaturedCarousel(
                              items: featured,
                              height: heroExtent,
                              contentTopInset: topInset,
                              onPageChanged: (index) => setState(
                                () => _featuredIndex = index,
                              ),
                            ),
                            if (topInset > 0)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: topInset,
                                child: RecommendationStatusBarScrim(
                                  color: pageBackground,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: Style.cardSpace),
                  sliver: _buildBody(colorScheme, state),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      );
    });
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
  );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? _buildRecommendationGrid(response, colorScheme)
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _buildRecommendationGrid(List<dynamic> response, ColorScheme scheme) {
    final featuredItems = controller.featuredItems;
    final sourceItems = response.whereType<BaseRcmdVideoItemModel>().toList();
    final visibleItems = withoutFeaturedRecommendations(
      sourceItems,
      featuredItems,
    );
    final markerIndex = controller.lastRefreshAt == null
        ? null
        : sourceItems
              .take(controller.lastRefreshAt!)
              .where(
                (item) => !featuredItems
                    .map(recommendationIdentity)
                    .contains(recommendationIdentity(item)),
              )
              .length;
    final itemCount = visibleItems.length + (markerIndex == null ? 0 : 1);
    return SliverGrid.builder(
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == itemCount - 1) controller.onLoadMore();
        if (markerIndex == index) {
          return GestureDetector(
            onTap: () => controller
              ..animateToTop()
              ..onRefresh(),
            child: Card(
              child: Container(
                alignment: Alignment.center,
                padding: const .symmetric(horizontal: 10),
                child: Text(
                  '上次看到这里\n点击刷新',
                  textAlign: .center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }
        final itemIndex = markerIndex != null && index > markerIndex
            ? index - 1
            : index;
        final item = visibleItems[itemIndex];
        final sourceIndex = response.indexOf(item);
        return VideoCardV(
          videoItem: item,
          onRemove: () {
            if (sourceIndex < 0) return;
            if (controller.lastRefreshAt case final marker?
                when sourceIndex < marker) {
              controller.lastRefreshAt = marker - 1;
            }
            controller.loadingState
              ..value.data!.removeAt(sourceIndex)
              ..refresh();
          },
        );
      },
    );
  }

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardVSkeleton(),
    ),
  );
}

/// Softens the cover behind the camera cutout without obscuring its controls.
class RecommendationStatusBarScrim extends StatelessWidget {
  const RecommendationStatusBarScrim({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .3), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

class RecommendationFeaturedCarousel extends StatefulWidget {
  const RecommendationFeaturedCarousel({
    super.key,
    required this.items,
    this.height = 340,
    this.contentTopInset = 0,
    this.onPageChanged,
  });

  final List<BaseRcmdVideoItemModel> items;
  final double height;
  final double contentTopInset;
  final ValueChanged<int>? onPageChanged;

  @override
  State<RecommendationFeaturedCarousel> createState() =>
      _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<RecommendationFeaturedCarousel>
    with WidgetsBindingObserver {
  double get height => widget.height;
  late final PageController _pageController = PageController(
    viewportFraction: 1,
  );
  int _index = 0;
  Timer? _autoAdvanceTimer;
  bool _appActive = true;

  @override
  void didUpdateWidget(covariant RecommendationFeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPageChanged?.call(0);
      });
    } else if (_index >= widget.items.length) {
      _index = widget.items.length - 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_index);
      }
      widget.onPageChanged?.call(_index);
    }
    _updateAutoAdvance();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updateAutoAdvance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAutoAdvance();
  }

  void _updateAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (!mounted ||
        !_appActive ||
        !TickerMode.valuesOf(context).enabled ||
        ImmersiveTokens.reduceMotionOf(context) ||
        widget.items.length < 2) {
      return;
    }
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _pageController.animateToPage(
        next,
        duration: ImmersiveTokens.reduceMotionOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
    } else if (notification is ScrollEndNotification) {
      _updateAutoAdvance();
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final duration = ImmersiveTokens.reduceMotionOf(context)
        ? Duration.zero
        : ImmersiveTokens.chromeDuration(context);
    return SizedBox(
      height: height,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.items.length,
          onPageChanged: (value) {
            setState(() => _index = value);
            widget.onPageChanged?.call(value);
            if (_autoAdvanceTimer == null) _updateAutoAdvance();
          },
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? _index.toDouble())
                    : _index.toDouble();
                final distance = (page - index).abs().clamp(0.0, 1.0);
                return Transform.scale(
                  scale: ImmersiveTokens.reduceMotionOf(context)
                      ? 1
                      : 1 - distance * .045,
                  child: child,
                );
              },
              child: _FeaturedCard(
                item: item,
                duration: duration,
                selectedIndex: _index,
                pageCount: widget.items.length,
                height: height,
                contentTopInset: widget.contentTopInset,
                onPlay: () => VideoCardV.openItem(item),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.duration,
    required this.selectedIndex,
    required this.pageCount,
    required this.height,
    required this.contentTopInset,
    required this.onPlay,
  });

  final BaseRcmdVideoItemModel item;
  final Duration duration;
  final int selectedIndex;
  final int pageCount;
  final double height;
  final double contentTopInset;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onPlay,
          behavior: HitTestBehavior.translucent,
        ),
        Positioned(
          // Up-name and view count sit above the title, starting at the
          // same left edge as the carousel dots.
          left: 18,
          right: 18,
          bottom: 104,
          height: 22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: ImmersiveTokens.contentChangeDuration(context),
              switchInCurve: ImmersiveTokens.settleCurve,
              switchOutCurve: ImmersiveTokens.contentCurve,
              transitionBuilder: (child, animation) {
                if (ImmersiveTokens.reduceMotionOf(context)) return child;
                final opacity = CurvedAnimation(
                  parent: animation,
                  curve: ImmersiveTokens.contentCurve,
                );
                return FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .97, end: 1).animate(opacity),
                    child: child,
                  ),
                );
              },
              child: Text(
                '${item.owner.name}  |  ${NumUtils.numFormat(item.stat.view)} 播放',
                key: ValueKey('featured-meta-${item.bvid}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .78),
                  fontWeight: FontWeight.w500,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          // Title starts at the carousel dots' left edge; keep room on the
          // right so it clears the play button moved to the bottom-right.
          left: 18,
          right: 80,
          bottom: 54,
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedSwitcher(
                duration: ImmersiveTokens.contentChangeDuration(context),
                switchInCurve: ImmersiveTokens.settleCurve,
                switchOutCurve: ImmersiveTokens.contentCurve,
                transitionBuilder: (child, animation) {
                  if (ImmersiveTokens.reduceMotionOf(context)) return child;
                  final opacity = CurvedAnimation(
                    parent: animation,
                    curve: ImmersiveTokens.contentCurve,
                  );
                  return FadeTransition(
                    opacity: opacity,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: .97, end: 1).animate(opacity),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  item.title,
                  textScaler: const TextScaler.linear(.94),
                  key: ValueKey('featured-title-${item.bvid}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          // Play button moves to the right; the carousel dots take the left.
          right: 18,
          bottom: 16,
          child: Semantics(
            button: true,
            label: '播放',
            child: SizedBox.square(
              dimension: 48,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlay,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 29,
                    color: Color(0xFF121212),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (pageCount > 1)
          Positioned(
            // Carousel dots move to the left, opposite the play button.
            left: 18,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < pageCount; index++)
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    margin: const .only(right: 4),
                    width: index == selectedIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: .56),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
