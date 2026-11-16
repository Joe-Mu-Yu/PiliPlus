import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' as miuix;

/// Project-wide entry point for HyperOS-style switches.
///
/// The app's selected preset remains the source of the checked primary color,
/// even beneath a locally overridden Material theme.
class PiliMiuixSwitch extends StatelessWidget {
  const PiliMiuixSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return miuix.MiuixSwitch(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}
