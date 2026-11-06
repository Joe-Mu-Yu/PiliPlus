import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/couple_space/view.dart';
import 'package:PiliPlus/pages/movies/view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new destinations preserve persisted indexes of existing tabs', () {
    expect(NavigationBarType.home.index, 0);
    expect(NavigationBarType.dynamics.index, 1);
    expect(NavigationBarType.mine.index, 2);
    expect(NavigationBarType.follow.index, 3);
    expect(NavigationBarType.follow.label, '直播');
    expect(NavigationBarType.recorderCenter.index, 4);
    expect(NavigationBarType.recorderCenter.label, '录制');
    expect(NavigationBarType.movies.index, 5);
    expect(NavigationBarType.movies.label, '影视');
    expect(NavigationBarType.movies.page, isA<MovieHomePage>());
    expect(NavigationBarType.coupleSpace.index, 6);
    expect(NavigationBarType.coupleSpace.label, '小窝');
    expect(NavigationBarType.coupleSpace.page, isA<CoupleSpacePage>());
  });

  test('saved navigation order hides mine and recording destinations', () {
    expect(
      NavigationBarType.fromSavedIndexes([2, 0, 1]),
      [
        NavigationBarType.home,
        NavigationBarType.dynamics,
        NavigationBarType.follow,
        NavigationBarType.movies,
        NavigationBarType.coupleSpace,
      ],
    );
    expect(
      NavigationBarType.fromSavedIndexes([0, 1, 2, 3, 4]),
      NavigationBarType.destinations,
    );
    expect(
      NavigationBarType.destinations,
      isNot(contains(NavigationBarType.mine)),
    );
    expect(
      NavigationBarType.destinations,
      isNot(contains(NavigationBarType.recorderCenter)),
    );
  });
}
