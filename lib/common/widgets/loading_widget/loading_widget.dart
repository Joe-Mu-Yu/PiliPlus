import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

/// Kept under the historical name to avoid touching every loading-state
/// branch. The implementation now follows MIUIX and paints a simple arc rather
/// than morphing and rotating complex paths on every frame.
const Widget m3eLoading = Center(child: PiliMiuixLoadingIndicator(size: 40));

const Widget linearLoading = SliverToBoxAdapter(
  child: PiliMiuixLinearLoadingIndicator(),
);

class PiliMiuixLoadingIndicator extends StatelessWidget {
  const PiliMiuixLoadingIndicator({
    super.key,
    this.progress,
    this.color,
    this.backgroundColor,
    this.strokeWidth =
        miuix.MiuixProgressIndicatorDefaults.defaultCircularStrokeWidth,
    this.size = miuix.MiuixProgressIndicatorDefaults.defaultCircularSize,
  });

  final double? progress;
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final defaultColors = miuix.MiuixProgressIndicatorDefaults.defaultColors(
      context,
    );
    final colors = color == null && backgroundColor == null
        ? defaultColors
        : miuix.MiuixProgressIndicatorColors(
            foregroundColor: color ?? defaultColors.foregroundColor,
            disabledForegroundColor: defaultColors.disabledForegroundColor,
            backgroundColor: backgroundColor ?? defaultColors.backgroundColor,
          );
    return RepaintBoundary(
      child: miuix.MiuixCircularProgressIndicator(
        progress: progress ?? (reduceMotion ? 0.25 : null),
        colors: colors,
        strokeWidth: strokeWidth,
        size: size,
      ),
    );
  }
}

class PiliMiuixLinearLoadingIndicator extends StatelessWidget {
  const PiliMiuixLinearLoadingIndicator({
    super.key,
    this.progress,
    this.color,
    this.backgroundColor,
    this.height = miuix.MiuixProgressIndicatorDefaults.defaultLinearHeight,
  });

  final double? progress;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final defaultColors = miuix.MiuixProgressIndicatorDefaults.defaultColors(
      context,
    );
    final colors = color == null && backgroundColor == null
        ? defaultColors
        : miuix.MiuixProgressIndicatorColors(
            foregroundColor: color ?? defaultColors.foregroundColor,
            disabledForegroundColor: defaultColors.disabledForegroundColor,
            backgroundColor: backgroundColor ?? defaultColors.backgroundColor,
          );
    return RepaintBoundary(
      child: miuix.MiuixLinearProgressIndicator(
        progress: progress ?? (reduceMotion ? 0.35 : null),
        colors: colors,
        height: height,
      ),
    );
  }
}

const Widget scrollableError = CustomScrollView(slivers: [HttpError()]);

Widget scrollErrorWidget({
  String? errMsg,
  VoidCallback? onReload,
  ScrollController? controller,
}) => CustomScrollView(
  controller: controller,
  slivers: [
    HttpError(
      errMsg: errMsg,
      onReload: onReload,
    ),
  ],
);
