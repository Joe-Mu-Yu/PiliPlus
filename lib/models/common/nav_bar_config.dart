import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/pure_live_follow/view.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/movies/view.dart';
import 'package:PiliPlus/pages/recorder_center/view.dart';
import 'package:material_ui/material_ui.dart';

enum NavigationBarType implements EnumWithLabel {
  home(
    '首页',
    Icon(Icons.home_outlined),
    Icon(Icons.home),
    HomePage(),
  ),
  dynamics(
    '动态',
    Icon(CustomIcons.motion_photos_on_outlined),
    Icon(CustomIcons.motion_photos_on),
    DynamicsPage(),
  ),
  mine(
    '我的',
    Icon(Icons.person_outline),
    Icon(Icons.person),
    MinePage(),
  ),
  follow(
    '直播',
    Icon(Icons.favorite_border),
    Icon(Icons.favorite),
    PureLiveFollowPage(),
  ),
  recorderCenter(
    '录制',
    Icon(Icons.fiber_manual_record_outlined),
    Icon(Icons.fiber_manual_record),
    RecorderCenterPage(),
  ),
  movies(
    '影视',
    Icon(Icons.movie_outlined),
    Icon(Icons.movie),
    MovieHomePage(),
  ),
  ;

  @override
  final String label;
  final Icon icon;
  final Icon selectIcon;
  final Widget page;

  const NavigationBarType(this.label, this.icon, this.selectIcon, this.page);

  static List<NavigationBarType> fromSavedIndexes(List<int>? indexes) {
    if (indexes == null || indexes.isEmpty) return values;
    final validIndexes = indexes
        .where((index) => index >= 0 && index < values.length)
        .toSet();
    return [
      ...validIndexes.map((index) => values[index]),
      for (final type in values)
        if (!validIndexes.contains(type.index)) type,
    ];
  }
}
