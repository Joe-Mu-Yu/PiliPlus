import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/anchor_info.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/base_info.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/room_info.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/data.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:pure_live/common/models/live_room.dart'
    show LiveRoom, LiveStatus;

void main() {
  group('BilibiliLivePlatformAdapter', () {
    test('parses only canonical room links on the Bilibili live host', () {
      expect(
        BilibiliLivePlatformAdapter.roomIdFromUrl(
          'https://live.bilibili.com/12345',
        ),
        '12345',
      );
      expect(
        BilibiliLivePlatformAdapter.roomIdFromUrl(
          'http://www.bilibili.com/12345',
        ),
        isNull,
      );
      expect(
        BilibiliLivePlatformAdapter.roomIdFromUrl(
          'https://live.bilibili.com.evil.test/12345',
        ),
        isNull,
      );
      expect(
        BilibiliLivePlatformAdapter.roomIdFromUrl(
          'https://user@live.bilibili.com/12345',
        ),
        isNull,
      );
      expect(
        BilibiliLivePlatformAdapter.roomIdFromUrl(
          'https://live.bilibili.com/0',
        ),
        isNull,
      );
    });

    test(
      'requires successful room metadata before producing a favorite',
      () async {
        final adapter = BilibiliLivePlatformAdapter(
          getRoomInfo: (_) async => Success(
            RoomInfoH5Data(
              roomInfo: RoomInfo(
                title: 'A live room',
                cover: 'https://img.test/cover.jpg',
              ),
              anchorInfo: AnchorInfo(
                baseInfo: BaseInfo(
                  uname: 'Anchor',
                  face: 'https://img.test/avatar.jpg',
                ),
              ),
            ),
          ),
          getPlayInfo: (_) async =>
              Success(RoomPlayInfoData(roomId: 123, liveStatus: 1)),
        );

        final favorite = await adapter.resolveFavorite(
          'https://live.bilibili.com/123',
        );

        expect(favorite.identityKey, 'bilibili:123');
        expect(favorite.title, 'A live room');
        expect(favorite.anchorName, 'Anchor');
        expect(favorite.status, LiveFavoriteStatus.live);
      },
    );

    test('rejects a room when platform lookup fails', () async {
      final adapter = BilibiliLivePlatformAdapter(
        getRoomInfo: (_) async => const Error('not found'),
        getPlayInfo: (_) async =>
            Success(RoomPlayInfoData(roomId: 123, liveStatus: 0)),
      );

      await expectLater(
        adapter.resolveFavorite('https://live.bilibili.com/123'),
        throwsA(isA<LiveRoomResolutionException>()),
      );
    });
  });

  group('DouyuLivePlatformAdapter', () {
    test('parses only a direct Douyu room URL', () {
      expect(
        DouyuLivePlatformAdapter.roomIdFromUrl('https://www.douyu.com/123'),
        '123',
      );
      expect(
        DouyuLivePlatformAdapter.roomIdFromUrl('https://douyu.com/123/'),
        '123',
      );
      expect(
        DouyuLivePlatformAdapter.roomIdFromUrl(
          'https://douyu.com.evil.test/123',
        ),
        isNull,
      );
      expect(
        DouyuLivePlatformAdapter.roomIdFromUrl('https://douyu.com/search/abc'),
        isNull,
      );
    });

    test('verifies a room and reads its current live state', () async {
      final adapter = DouyuLivePlatformAdapter(
        getRoomInfo: (_) async => {
          'room_id': 456,
          'room_name': 'Douyu live',
          'owner_name': 'Host',
          'room_pic': 'https://img.test/cover.jpg',
          'owner_avatar': 'https://img.test/avatar.jpg',
          'show_status': 1,
          'videoLoop': 0,
          'room_biz_all': {'hot': 900},
        },
      );

      final favorite = await adapter.resolveFavorite(
        'https://www.douyu.com/123',
      );

      expect(favorite.identityKey, 'douyu:456');
      expect(favorite.status, LiveFavoriteStatus.live);
      expect(favorite.anchorName, 'Host');
    });
  });

  group('DouyinLivePlatformAdapter', () {
    test('parses a canonical Douyin live link and ignores tracking query', () {
      expect(
        DouyinLivePlatformAdapter.roomIdFromUrl(
          'https://live.douyin.com/106100309724?anchor_id=3593657624831155&category_name=all',
        ),
        '106100309724',
      );
      expect(
        DouyinLivePlatformAdapter.roomIdFromUrl(
          'https://live.douyin.com.evil.test/106100309724',
        ),
        isNull,
      );
      expect(
        DouyinLivePlatformAdapter.roomIdFromUrl(
          'https://live.douyin.com/room/106100309724',
        ),
        isNull,
      );
    });

    test(
      'uses Pure Live recording room resolution before creating a favorite',
      () async {
        String? requestedRoomId;
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailForRecording:
              ({required platform, required roomId}) async {
                expect(platform, 'douyin');
                requestedRoomId = roomId;
                return LiveRoom(
                  roomId: roomId,
                  platform: 'douyin',
                  title: 'Authorized live room',
                  nick: 'Anchor',
                  cover: 'https://img.test/cover.jpg',
                  link: 'https://live.douyin.com/$roomId',
                  liveStatus: LiveStatus.live,
                  status: true,
                );
              },
        );

        final favorite = await adapter.resolveFavorite(
          'https://live.douyin.com/106100309724?anchor_id=3593657624831155',
        );

        expect(requestedRoomId, '106100309724');
        expect(favorite.identityKey, 'douyin:106100309724');
        expect(favorite.roomUrl, 'https://live.douyin.com/106100309724');
        expect(favorite.title, 'Authorized live room');
        expect(favorite.anchorName, 'Anchor');
        expect(favorite.status, LiveFavoriteStatus.live);
      },
    );

    test('keeps a verified offline room out of the live bucket', () async {
      final adapter = DouyinLivePlatformAdapter(
        getRoomDetailForRecording:
            ({required platform, required roomId}) async => LiveRoom(
              roomId: roomId,
              platform: platform,
              title: 'Offline room',
              liveStatus: LiveStatus.offline,
              status: false,
            ),
      );

      final favorite = await adapter.resolveFavorite(
        'https://live.douyin.com/106100309724',
      );

      expect(favorite.status, LiveFavoriteStatus.offline);
    });

    test(
      'does not create a favorite when room status cannot be verified',
      () async {
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailForRecording:
              ({
                required platform,
                required roomId,
              }) async => LiveRoom(
                roomId: roomId,
                platform: platform,
                liveStatus: LiveStatus.unknown,
              ),
        );

        await expectLater(
          adapter.resolveFavorite('https://live.douyin.com/106100309724'),
          throwsA(isA<LiveRoomResolutionException>()),
        );
      },
    );
  });

  group('LiveFavoriteAddService', () {
    test(
      'resolves a link without writing to the legacy favorite store',
      () async {
        final store = _MemoryFavoriteStore();
        final service = LiveFavoriteAddService(
          adapters: [
            DouyinLivePlatformAdapter(
              getRoomDetailForRecording:
                  ({required platform, required roomId}) async => LiveRoom(
                    roomId: roomId,
                    platform: platform,
                    title: 'Authorized live room',
                    liveStatus: LiveStatus.live,
                  ),
            ),
          ],
          repository: LiveFavoriteRepository(store),
        );

        final favorite = await service.resolveFromLink(
          'https://live.douyin.com/106100309724',
        );

        expect(favorite.identityKey, 'douyin:106100309724');
        expect(store.values, isEmpty);
      },
    );

    test(
      'does not persist a link when no platform adapter accepts it',
      () async {
        final store = _MemoryFavoriteStore();
        final service = LiveFavoriteAddService(
          adapters: const [],
          repository: LiveFavoriteRepository(store),
        );

        await expectLater(
          service.addFromLink('https://unknown.example/room'),
          throwsA(isA<LiveRoomResolutionException>()),
        );
        expect(store.values, isEmpty);
      },
    );
  });
}

class _MemoryFavoriteStore implements LiveFavoriteStore {
  List<Map<String, Object?>> values = [];

  @override
  Future<List<Map<String, Object?>>> read() async => values;

  @override
  Future<void> write(List<Map<String, Object?>> favorites) async {
    values = favorites;
  }
}
