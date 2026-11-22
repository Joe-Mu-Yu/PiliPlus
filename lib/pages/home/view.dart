import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/common/widgets/immersive/press_scale_listener.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _colorScheme = ColorScheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    Widget buildTopActions() {
      final scheme = ColorScheme.of(context);
      final reduceMotion = ImmersiveTokens.reduceMotionOf(context);
      return Material(
        color: scheme.surfaceContainer.withValues(
          alpha: _mainController.floatingNavBar ? .4 : 1,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<HomeTabType>(
          tooltip: '首页频道',
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_horiz_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: scheme.onSurface,
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
          ),
          popUpAnimationStyle: AnimationStyle(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            reverseDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
            reverseCurve: reduceMotion ? Curves.linear : Curves.easeInCubic,
          ),
          onSelected: _homeController.selectTab,
          itemBuilder: (context) => [
            for (final tab in HomeTabType.values)
              PopupMenuItem(value: tab, child: Text(tab.label)),
          ],
        ),
      );
    }

    return Material(
      type: MaterialType.canvas,
      color: _colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                onBuild(
                  tabBarView(
                    controller: _homeController.tabController,
                    children: [
                      for (final tab in _homeController.tabs)
                        HomeTabViewport(tab: tab, child: tab.page),
                    ],
                  ),
                ),
                Positioned(
                  top: MediaQuery.viewPaddingOf(context).top + 12,
                  right: Style.safeSpace + 8,
                  child: PressScaleListener(child: buildTopActions()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Only recommendations extend beneath the status bar. Keep the other tab
/// viewports below the camera cutout without changing their PageView state.
class HomeTabViewport extends StatelessWidget {
  const HomeTabViewport({super.key, required this.tab, required this.child});

  final HomeTabType tab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tab == HomeTabType.rcmd) return child;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.viewPaddingOf(context).top),
      child: MediaQuery.removeViewPadding(
        context: context,
        removeTop: true,
        child: child,
      ),
    );
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(() {
      if (mainController.accountService.isLogin.value) {
        return Stack(
          clipBehavior: .none,
          children: [
            NetworkImgLayer(
              type: .avatar,
              width: 34,
              height: 34,
              src: mainController.accountService.face.value,
            ),
            Positioned.fill(
              child: Material(
                type: .transparency,
                child: InkWell(
                  onTap: mainController.toMinePage,
                  splashColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  customBorder: const CircleBorder(),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Obx(
                () => MineController.anonymity.value
                    ? IgnorePointer(
                        child: Container(
                          padding: const .all(2),
                          decoration: BoxDecoration(
                            shape: .circle,
                            color: colorScheme.secondaryContainer,
                          ),
                          child: Icon(
                            size: 14,
                            MdiIcons.incognito,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }
      return SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          tooltip: '点击登录',
          style: IconButton.styleFrom(
            padding: .zero,
            backgroundColor: colorScheme.onInverseSurface,
          ),
          onPressed: mainController.toMinePage,
          icon: Icon(
            Icons.person_rounded,
            size: 22,
            color: colorScheme.primary,
          ),
        ),
      );
    }),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(() {
    if (mainController.accountService.isLogin.value) {
      final count = mainController.msgUnReadCount.value;
      final isNumBadge = mainController.msgBadgeMode == .number;
      return IconButton(
        tooltip: '消息',
        onPressed: () {
          mainController
            ..clearUnreadMsg()
            ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
          Get.toNamed('/whisper');
        },
        icon: Badge(
          isLabelVisible:
              mainController.msgBadgeMode != .hidden && count != null,
          alignment: isNumBadge
              ? const Alignment(0.0, -0.85)
              : const Alignment(1.0, -0.85),
          label: isNumBadge && count != null ? Text(count) : null,
          child: const Icon(Icons.notifications_none),
        ),
      );
    }
    return const SizedBox.shrink();
  });
}
