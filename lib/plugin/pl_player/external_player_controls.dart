import 'package:PiliPlus/pages/video/widgets/header_control.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/common_btn.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/play_pause_btn.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ExternalPlayerHeaderControl extends StatefulWidget {
  const ExternalPlayerHeaderControl({
    required this.title,
    required this.controller,
    this.onBack,
    this.onRefresh,
    this.onMore,
    super.key,
  });

  final String title;
  final PlPlayerController controller;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onMore;

  @override
  State<ExternalPlayerHeaderControl> createState() =>
      _ExternalPlayerHeaderControlState();
}

class _ExternalPlayerHeaderControlState
    extends State<ExternalPlayerHeaderControl>
    with TimeBatteryMixin {
  @override
  PlPlayerController get plPlayerController => widget.controller;

  @override
  bool get horizontalScreen => true;

  @override
  bool get isFullScreen => plPlayerController.isFullScreen.value;

  @override
  bool get isPortrait => plPlayerController.isVertical;

  @override
  Widget build(BuildContext context) {
    showCurrTimeIfNeeded(isFullScreen);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          if (widget.onBack != null || isFullScreen)
            ComBtn(
              height: 30,
              tooltip: widget.onBack == null ? '退出全屏' : '返回',
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Colors.white,
              ),
              onTap:
                  widget.onBack ??
                  () => plPlayerController.triggerFullScreen(status: false),
            ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          ...?timeBatteryWidgets,
          if (widget.onRefresh case final onRefresh?)
            ComBtn(
              height: 30,
              tooltip: '刷新播放源',
              icon: const Icon(Icons.refresh, size: 19, color: Colors.white),
              onTap: onRefresh,
            ),
          if (widget.onMore case final onMore?)
            ComBtn(
              height: 30,
              tooltip: '更多',
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: Colors.white,
              ),
              onTap: onMore,
            ),
        ],
      ),
    );
  }
}

class ExternalPlayerBottomControl extends StatelessWidget {
  const ExternalPlayerBottomControl({
    required this.controller,
    this.qualityLabel,
    this.lineLabel,
    this.onQuality,
    this.onLine,
    this.onDanmaku,
    this.danmakuEnabled = false,
    this.onAudioOnly,
    this.audioOnly = false,
    super.key,
  });

  final PlPlayerController controller;
  final String? qualityLabel;
  final String? lineLabel;
  final VoidCallback? onQuality;
  final VoidCallback? onLine;
  final VoidCallback? onDanmaku;
  final bool danmakuEnabled;
  final VoidCallback? onAudioOnly;
  final bool audioOnly;

  Future<void> _showCompactOptions(BuildContext context) async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('播放选项')),
            if (qualityLabel case final label?)
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('画质'),
                subtitle: Text(label),
                onTap: () => Navigator.pop(context, onQuality),
              ),
            if (lineLabel case final label?)
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('线路'),
                subtitle: Text(label),
                onTap: () => Navigator.pop(context, onLine),
              ),
            for (final fit in VideoFitType.values)
              ListTile(
                leading: Icon(
                  controller.videoFit.value == fit
                      ? Icons.check_circle
                      : Icons.aspect_ratio,
                ),
                title: Text('画面比例 · ${fit.desc}'),
                onTap: () => Navigator.pop(
                  context,
                  () => controller.toggleVideoFit(fit),
                ),
              ),
          ],
        ),
      ),
    );
    action?.call();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 560 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.15;
          return Row(
            children: [
              PlayOrPauseButton(plPlayerController: controller),
              if (onAudioOnly case final callback?)
                ComBtn(
                  height: 30,
                  tooltip: audioOnly ? '恢复画面' : '仅听声音',
                  icon: Icon(
                    audioOnly ? Icons.music_note_rounded : Icons.headphones,
                    size: 19,
                    color: Colors.white,
                  ),
                  onTap: callback,
                ),
              if (onDanmaku case final callback?)
                ComBtn(
                  height: 30,
                  tooltip: danmakuEnabled ? '关闭弹幕' : '开启弹幕',
                  icon: Icon(
                    danmakuEnabled ? Icons.subtitles : Icons.subtitles_off,
                    size: 19,
                    color: Colors.white,
                  ),
                  onTap: callback,
                ),
              const Spacer(),
              if (compact)
                ComBtn(
                  height: 30,
                  tooltip: '播放选项',
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  onTap: () => _showCompactOptions(context),
                )
              else ...[
                if (qualityLabel case final label?)
                  TextButton(
                    onPressed: onQuality,
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (lineLabel case final label?)
                  TextButton(
                    onPressed: onLine,
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                Obx(() {
                  final fit = controller.videoFit.value;
                  return PopupMenuButton<VideoFitType>(
                    tooltip: '画面比例',
                    initialValue: fit,
                    color: Colors.black.withValues(alpha: 0.8),
                    onSelected: controller.toggleVideoFit,
                    itemBuilder: (context) => VideoFitType.values
                        .map(
                          (value) => PopupMenuItem(
                            value: value,
                            child: Text(
                              value.desc,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        fit.desc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ],
              Obx(
                () => ComBtn(
                  height: 30,
                  tooltip: controller.isFullScreen.value ? '退出全屏' : '全屏',
                  icon: Icon(
                    controller.isFullScreen.value
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    size: 21,
                    color: Colors.white,
                  ),
                  onTap: () => controller.triggerFullScreen(
                    status: !controller.isFullScreen.value,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
