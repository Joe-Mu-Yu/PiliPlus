import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

Widget iconButton({
  BuildContext? context,
  String? tooltip,
  required Widget icon,
  required VoidCallback? onPressed,
  double size = 36,
  double? iconSize,
  Color? bgColor,
  Color? iconColor,
}) {
  Color? backgroundColor = bgColor;
  Color? foregroundColor = iconColor;
  if (context != null) {
    final colors = miuix.MiuixTheme.of(context).colors;
    backgroundColor = colors.secondaryVariant;
    foregroundColor = colors.onSecondaryVariant;
  }
  final effectiveSize = size < miuix.MiuixIconButtonDefaults.minWidth
      ? miuix.MiuixIconButtonDefaults.minWidth
      : size;
  Widget button = miuix.MiuixIconButton(
    onPressed: onPressed,
    minWidth: effectiveSize,
    minHeight: effectiveSize,
    cornerRadius: effectiveSize,
    backgroundColor: backgroundColor,
    child: IconTheme.merge(
      data: IconThemeData(
        size: iconSize ?? size / 2,
        color: foregroundColor,
      ),
      child: icon,
    ),
  );
  if (tooltip?.isNotEmpty == true) {
    button = Tooltip(message: tooltip!, child: button);
  }
  return button;
}
