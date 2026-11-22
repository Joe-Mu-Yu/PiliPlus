import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

String recommendationIdentity(BaseRcmdVideoItemModel item) =>
    item.cid?.toString() ??
    item.bvid ??
    item.aid?.toString() ??
    item.uri ??
    item.title;

List<BaseRcmdVideoItemModel> withoutFeaturedRecommendations(
  List<BaseRcmdVideoItemModel> items,
  Iterable<BaseRcmdVideoItemModel> featured,
) {
  final featuredIds = featured.map(recommendationIdentity).toSet();
  return items
      .where((item) => !featuredIds.contains(recommendationIdentity(item)))
      .toList(growable: false);
}

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  List<BaseRcmdVideoItemModel> get featuredItems {
    if (loadingState.value case Success(:final response)
        when response != null) {
      return response.whereType<BaseRcmdVideoItemModel>().take(5).toList();
    }
    return const [];
  }

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    return _loadRecommendations();
  }

  Future<LoadingState> _loadRecommendations() async {
    try {
      return appRcmd
          ? await VideoHttp.rcmdVideoListApp(freshIdx: page)
          : await VideoHttp.rcmdVideoList(freshIdx: page, ps: 20);
    } catch (error) {
      return Error('推荐加载失败：$error');
    }
  }

  @override
  bool handleError(String? errMsg) {
    if (!enableSaveLastData) return false;
    return loadingState.value is Success;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
