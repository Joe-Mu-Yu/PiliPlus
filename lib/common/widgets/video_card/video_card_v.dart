import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/common/widgets/immersive/press_scale_listener.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatefulWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool showContent;
  final double? coverAspectRatio;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
    this.onTap,
    this.showContent = true,
    this.coverAspectRatio,
  });

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  static Future<void> openItem(BaseRcmdVideoItemModel item) async {
    final heroTag = Utils.makeHeroTag(item.cid ?? item.bvid ?? item.aid);
    switch (item.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: item.param!, heroTag: heroTag);
        break;
      case 'av':
        final bvid = item.bvid ?? IdUtils.av2bv(item.aid!);
        var cid = item.cid;
        Dimension? dimension;
        var isVertical = false;
        if (item is RcmdVideoItemAppModel) {
          if (item.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          final result = await SearchHttp.ab2cWithDimension(
            aid: item.aid,
            bvid: bvid,
          );
          if (result != null) {
            cid = result.cid;
            dimension = result.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: item.aid,
            bvid: bvid,
            cid: cid,
            cover: item.cover,
            title: item.title,
            isVertical: isVertical,
            dimension: dimension,
            heroTag: heroTag,
          );
        }
        break;
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(item.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (item.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(item.uri!);
        }
    }
  }

  @override
  State<VideoCardV> createState() => _VideoCardVState();
}

class _VideoCardVState extends State<VideoCardV> {
  BaseRcmdVideoItemModel get videoItem => widget.videoItem;
  VoidCallback? get onRemove => widget.onRemove;

  late String _heroTag;
  @override
  void initState() {
    super.initState();
    _heroTag = Utils.makeHeroTag(
      videoItem.cid ?? videoItem.bvid ?? videoItem.aid,
    );
  }

  @override
  void didUpdateWidget(covariant VideoCardV oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.videoItem, videoItem)) {
      _heroTag = Utils.makeHeroTag(
        videoItem.cid ?? videoItem.bvid ?? videoItem.aid,
      );
    }
  }

  Future<void> onPushDetail() async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!, heroTag: _heroTag);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
            heroTag: _heroTag,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        VideoCardHero(
          tag: _heroTag,
          surfaceColor: Theme.of(context).colorScheme.surfaceContainer,
          child: PressScaleListener(
            child: Card(
              margin: .zero,
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ImmersiveTokens.cardRadius),
                side: BorderSide(
                  color: ImmersiveTokens.cardOutline(
                    Theme.of(context).colorScheme,
                  ),
                  width: ImmersiveTokens.hairline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap ?? onPushDetail,
                onLongPress: onLongPress,
                onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
                borderRadius: BorderRadius.circular(ImmersiveTokens.cardRadius),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    if (widget.coverAspectRatio == null)
                      AspectRatio(
                        aspectRatio: Style.aspectRatio,
                        child: _cover(context),
                      )
                    else
                      Expanded(child: _cover(context)),
                    if (widget.showContent) content(context),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (videoItem.goto == 'av')
          Positioned(
            right: -5,
            bottom: -2,
            width: 29,
            height: 29,
            child: VideoPopupMenu(
              iconSize: 17,
              videoItem: videoItem,
              onRemove: onRemove,
            ),
          ),
      ],
    );
  }

  Widget _cover(BuildContext context) => LayoutBuilder(
    builder: (context, boxConstraints) {
      final maxWidth = boxConstraints.maxWidth;
      final maxHeight = boxConstraints.maxHeight;
      return Stack(
        clipBehavior: .none,
        children: [
          NetworkImgLayer(
            src: videoItem.cover,
            width: maxWidth,
            height: maxHeight,
            borderRadius: const .vertical(
              top: .circular(ImmersiveTokens.cardRadius),
            ),
          ),
          if (videoItem.duration > 0)
            PBadge(
              bottom: 6,
              right: 7,
              size: .small,
              type: .gray,
              text: DurationUtils.formatDuration(videoItem.duration),
            ),
        ],
      );
    },
  );

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const .fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Text(
                videoItem.title,
                maxLines: 2,
                overflow: .ellipsis,
                style: const TextStyle(height: 1.38),
              ),
            ),
            videoStat(theme),
            Row(
              spacing: 2,
              children: [
                if (videoItem.goto == 'bangumi')
                  PBadge(
                    text: videoItem.pgcBadge,
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.rcmdReason != null)
                  PBadge(
                    text: videoItem.rcmdReason,
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                if (videoItem.goto == 'picture')
                  const PBadge(
                    text: '动态',
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.isFollowed)
                  const PBadge(
                    text: '已关注',
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                Expanded(
                  flex: 1,
                  child: Text(
                    videoItem.owner.name.toString(),
                    maxLines: 1,
                    overflow: .clip,
                    semanticsLabel: 'UP：${videoItem.owner.name}',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: theme.textTheme.labelMedium!.fontSize,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                if (videoItem.goto == 'av') const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget videoStat(ThemeData theme) {
    return Row(
      children: [
        StatWidget(type: .play, value: videoItem.stat.view),
        if (videoItem.goto != 'picture') ...[
          const SizedBox(width: 4),
          StatWidget(type: .danmaku, value: videoItem.stat.danmu),
        ],
        if (videoItem is RcmdVideoItemModel) ...[
          const Spacer(),
          Text.rich(
            maxLines: 1,
            TextSpan(
              style: TextStyle(
                fontSize: theme.textTheme.labelSmall!.fontSize,
                color: theme.colorScheme.outline.withValues(alpha: 0.8),
              ),
              text: DateFormatUtils.dateFormat(
                videoItem.pubdate,
                short: VideoCardV.shortFormat,
                long: VideoCardV.longFormat,
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }
}
