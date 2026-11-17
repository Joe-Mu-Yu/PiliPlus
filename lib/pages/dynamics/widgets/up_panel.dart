import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/live_follow/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UpPanel extends StatefulWidget {
  const UpPanel({
    super.key,
    required this.upData,
    required this.dynamicsController,
  });

  final FollowUpModel upData;
  final DynamicsController dynamicsController;

  @override
  State<UpPanel> createState() => _UpPanelState();
}

class _UpPanelState extends State<UpPanel> {
  late final controller = widget.dynamicsController;

  /// The panel always renders as a horizontal row under the category tabs;
  /// the legacy side/drawer positions are no longer used.
  static const bool isTop = true;

  /// "更多" opens the account-follow (UP) detail page.
  void toAccountFollowPage() => Get.toNamed('/follow');

  void toLiveFollowPage() => Get.to(const LiveFollowPage());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upData = widget.upData;
    final upList = upData.upList;
    final liveList = upData.liveUsers?.items;
    if (isTop) {
      final List<UpItem> panelItems = [
        if (controller.showLiveUp) ...?liveList,
        UpItem(face: '', uname: '全部动态', mid: -1),
        UpItem(
          uname: '我',
          face: controller.accountService.face.value,
          mid: Accounts.main.mid,
        ),
        ...?upList,
      ];
      // Reference-style horizontal panel under the category tabs: a titled
      // avatar row with a trailing "more" entry to the account-follow page.
      return Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .fromLTRB(16, 10, 8, 2),
            child: Row(
              children: [
                Text(
                  '最常访问',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: toAccountFollowPage,
                  style: TextButton.styleFrom(
                    padding: const .symmetric(horizontal: 8),
                  ),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      Text(
                        '更多',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 92,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                final metrics = notification.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 300) {
                  controller.onLoadMore();
                }
                return false;
              },
              child: ListView.custom(
                scrollDirection: .horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                controller: controller.scrollController,
                childrenDelegate: SliverChildBuilderDelegate(
                  (context, index) => upItemBuild(theme, panelItems[index]),
                  childCount: panelItems.length,
                ),
              ),
            ),
          ),
          // Hairline separator between the access panel and the feed so the
          // three sections stay visually distinct.
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
          ),
        ],
      );
    }
    return CustomScrollView(
      scrollDirection: .vertical,
      physics: const AlwaysScrollableScrollPhysics(),
      controller: controller.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () => setState(() {
              controller.showLiveUp = !controller.showLiveUp;
            }),
            onLongPress: toLiveFollowPage,
            onSecondaryTap: PlatformUtils.isMobile ? null : toLiveFollowPage,
            child: Container(
              alignment: .center,
              height: 60,
              child: Text.rich(
                textAlign: .center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Live(${upData.liveUsers?.count ?? 0})',
                    ),
                    const TextSpan(text: '\n'),
                    WidgetSpan(
                      alignment: .middle,
                      child: Icon(
                        controller.showLiveUp
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (controller.showLiveUp && liveList != null && liveList.isNotEmpty)
          SliverList.builder(
            itemCount: liveList.length,
            itemBuilder: (context, index) {
              return upItemBuild(theme, liveList[index]);
            },
          ),
        SliverToBoxAdapter(
          child: upItemBuild(theme, UpItem(face: '', uname: '全部动态', mid: -1)),
        ),
        SliverToBoxAdapter(
          child: Obx(
            () => upItemBuild(
              theme,
              UpItem(
                uname: '我',
                face: controller.accountService.face.value,
                mid: Accounts.main.mid,
              ),
            ),
          ),
        ),
        if (upList != null && upList.isNotEmpty)
          SliverList.builder(
            itemCount: upList.length,
            itemBuilder: (context, index) {
              return upItemBuild(theme, upList[index]);
            },
          ),
        if (!isTop) const SliverToBoxAdapter(child: SizedBox(height: 200)),
      ],
    );
  }

  void _onSelect(UpItem item) {
    item.hasUpdate = false;
    controller.onSelectUp(item.mid);
    setState(() {});
  }

  Widget upItemBuild(ThemeData theme, UpItem item) {
    final currentMid = controller.currentMid;
    final isLive = item is LiveUserItem;
    final isCurrent = isLive || currentMid == item.mid || currentMid == -1;

    final isAll = item.mid == -1;
    void toMemberPage() => Get.toNamed('/member?mid=${item.mid}');

    Widget avatar;
    if (isAll) {
      avatar = DecoratedBox(
        decoration: const BoxDecoration(
          shape: .circle,
          color: Color(0xFF5CB67B),
        ),
        child: Image.asset(
          width: 44,
          height: 44,
          cacheWidth: 44.cacheSize(context),
          Assets.logo2,
          color: Colors.white,
        ),
      );
    } else {
      avatar = Padding(
        padding: const .symmetric(horizontal: 4),
        child: NetworkImgLayer(
          width: 44,
          height: 44,
          src: item.face,
          type: .avatar,
        ),
      );
      if (isLive) {
        avatar = Stack(
          clipBehavior: .none,
          children: [
            avatar,
            Positioned(
              top: isLive && !isTop ? -5 : 0,
              right: -6,
              child: Badge(
                label: const Text(' Live '),
                textColor: theme.colorScheme.onSecondaryContainer,
                backgroundColor: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.75),
              ),
            ),
          ],
        );
      } else if (item.hasUpdate ?? false) {
        avatar = Stack(
          clipBehavior: .none,
          children: [
            avatar,
            Positioned(
              top: 0,
              right: 4,
              child: Badge(
                smallSize: 8,
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        );
      }
    }

    return SizedBox(
      height: 92,
      child: InkWell(
        onTap: () {
          feedBack();
          if (isLive) {
            PageUtils.toLiveRoom(item.roomId);
          } else {
            _onSelect(item);
          }
        },
        // onDoubleTap: isLive ? () => _onSelect(data) : null,
        onLongPress: !isAll ? toMemberPage : null,
        onSecondaryTap: !isAll && !PlatformUtils.isMobile ? toMemberPage : null,
        child: Opacity(
          opacity: isCurrent ? 1 : 0.6,
          child: Column(
            spacing: 6,
            mainAxisSize: .min,
            mainAxisAlignment: .center,
            children: [
              avatar,
              Padding(
                padding: const .fromLTRB(2, 0, 2, 4),
                child: SizedBox(
                  width: 56,
                  child: Text(
                    item.uname!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: .center,
                    style: TextStyle(
                      color: currentMid == item.mid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      height: 1.15,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
