import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

enum MainType { sideBar, bottomNav, body }

/// Applies the host safe-area padding without changing the destination tree.
///
/// A destination that paints its own system-bar insets can opt into the full
/// viewport. Keeping [Padding] in both modes prevents switching destinations
/// from recreating the nested [PageView] or its platform views.
class MainBodyViewport extends StatelessWidget {
  const MainBodyViewport({
    super.key,
    required this.safePadding,
    required this.extendIntoSystemBars,
    this.extendIntoTopSystemBar = false,
    required this.child,
  });

  final EdgeInsets safePadding;
  final bool extendIntoSystemBars;
  final bool extendIntoTopSystemBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = extendIntoSystemBars
        ? EdgeInsets.only(
            top: extendIntoTopSystemBar ? 0 : safePadding.top,
          )
        : safePadding;
    return Padding(padding: padding, child: child);
  }
}

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout();
  }
}

class _RenderMainLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<MainType, RenderBox>,
        SlottedLayoutMixin {
  RenderBox? get sideBar => childForSlot(.sideBar);
  RenderBox? get bottomNav => childForSlot(.bottomNav);
  RenderBox get body => childForSlot(.body)!;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final sideBar = this.sideBar;
    if (sideBar != null) {
      final sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      setOffset(sideBar, .zero);

      bodyOffset = Offset(sideBarWidth, 0);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth - sideBarWidth,
        height: constraints.maxHeight,
      );
    } else {
      final bottomNav = this.bottomNav;
      if (bottomNav != null) {
        final bottomNavSize = ChildLayoutHelper.layoutChild(
          bottomNav,
          constraints.loosen(),
        );
        setOffset(
          bottomNav,
          Offset(
            (constraints.maxWidth - bottomNavSize.width) / 2,
            constraints.maxHeight - bottomNavSize.height,
          ),
        );
      }

      bodyOffset = .zero;
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      );
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    doPaint(sideBar);
    doPaint(body);
    doPaint(bottomNav);
  }
}
