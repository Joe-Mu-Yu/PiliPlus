import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide DraggableScrollableSheet;

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  Widget upPanelPart(ColorScheme colorScheme) {
    // Let the panel size itself: the previous fixed 106dp box clipped the
    // avatar labels when the text scale grew.
    return Material(
      type: .transparency,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 300) {
            _dynamicsController.onLoadMore();
          }
          return false;
        },
        child: Obx(
          () => _buildUpPanel(_dynamicsController.loadingState.value),
        ),
      ),
    );
  }

  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != .dynamics &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final child = tabBarView(
      controller: _dynamicsController.tabController,
      children: DynamicsTabType.values
          .map(
            (e) => DynamicsTabPage(
              dynamicsType: e,
              key: ValueKey(e),
            ),
          )
          .toList(),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        primary: false,
        resizeToAvoidBottomInset: false,
        backgroundColor: colorScheme.surface,
        appBar: null,
        body: Column(
          children: [
            upPanelPart(colorScheme),
            Expanded(child: onBuild(child)),
          ],
        ),
      ),
    );
  }
}
