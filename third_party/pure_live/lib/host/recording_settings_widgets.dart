import 'package:material_ui/material_ui.dart';
import 'package:pure_live/host/recording_common.dart' show Obx, RxBool;

/// Material-based settings widgets for the PiliPlus host integration.
///
/// These keep Pure Live's recorder settings behavior while avoiding imports
/// from Pure Live's application-wide widget barrel and its separate GetX tree.
extension RecordingSettingsWidgets on BuildContext {
  Widget buildGroupTitle(String title) {
    final theme = Theme.of(this);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget buildModernCard(List<Widget> children) {
    final theme = Theme.of(this);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget buildTile({
    required String title,
    IconData? icon,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isLong = false,
  }) {
    final theme = Theme.of(this);
    return ListTile(
      leading: icon == null
          ? null
          : Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: isLong ? null : 2,
              overflow: isLong ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget buildSwitchTile({
    required String title,
    required RxBool value,
    IconData? icon,
    String? subtitle,
    bool isLong = false,
    bool enabled = true,
    bool autoCommit = true,
    ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(this);
    return Obx(
      () => SwitchListTile(
        secondary: icon == null
            ? null
            : Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: isLong ? null : 2,
                overflow: isLong ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
        value: value.value,
        onChanged: enabled
            ? (next) {
                if (autoCommit) value.value = next;
                onChanged?.call(next);
              }
            : null,
      ),
    );
  }

  Widget buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Text(
                displayValue,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
