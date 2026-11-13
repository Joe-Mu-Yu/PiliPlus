import 'dart:io' show Platform;

import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;

typedef AvboxViewBuilder = Widget Function(BuildContext context);

class MovieHomePage extends StatelessWidget {
  const MovieHomePage({
    super.key,
    @visibleForTesting this.isAndroid,
    @visibleForTesting this.avboxViewBuilder,
  });

  @visibleForTesting
  final bool? isAndroid;

  @visibleForTesting
  final AvboxViewBuilder? avboxViewBuilder;

  bool get _isAndroid => isAndroid ?? Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    if (_isAndroid) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        // AVBox paints through the host navigation area. Its Compose lists
        // reserve the tappable bottom inset; clipping the entire PlatformView
        // here exposes Flutter's background below the floating glass bar.
        child:
            avboxViewBuilder?.call(context) ??
            const AndroidView(
              viewType: 'com.aritxonly.hyperpiliplus/avbox_view',
              layoutDirection: TextDirection.ltr,
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(title: const Text('影视')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              color: colors.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phonelink_erase_rounded,
                      size: 52,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '当前平台暂不支持影视',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'AVBox 集成目前仅支持 Android；原 Gimy 网页影视入口已移除。',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'AVBox · AGPL-3.0 · 源码固定版本 72e007e',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => PageUtils.launchURL(
                        'https://github.com/XiaochangXu/AVBox/tree/'
                        '72e007e398d2a5e924f20e7039fd5fcd49c506f9',
                      ),
                      icon: const Icon(Icons.code_rounded),
                      label: const Text('查看 AVBox 对应源码'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
