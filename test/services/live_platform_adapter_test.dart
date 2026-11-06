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

  group('PureLiveDirectLinkAdapter', () {
    test('accepts direct stream links and rejects unrelated URLs', () {
      for (final link in [
        'https://cdn.example/live.m3u8?token=abc',
        'http://cdn.example:8080/live.m3u8',
        'https://cdn.example/live.flv',
        'https://cdn.example/live.mp4',
      ]) {
        expect(PureLiveDirectLinkAdapter.uriFromLink(link), isNotNull);
      }
      for (final link in [
        'http://cdn.example/channel.m3u',
        'https://cdn.example/watch/123',
        'https://user@cdn.example/live.m3u8',
        'https://cdn.example/live.m3u8#fragment',
        'file:///tmp/live.m3u8',
      ]) {
        expect(PureLiveDirectLinkAdapter.uriFromLink(link), isNull);
      }
    });

    test(
      'uses Pure Live IPTV URL resolution for direct stream links',
      () async {
        final adapter = PureLiveDirectLinkAdapter();
        final favorite = await adapter.resolveFavorite(
          'https://cdn.example/live.m3u8?token=abc',
        );
        expect(favorite.platformId, 'pure_live');
        expect(favorite.roomUrl, 'https://cdn.example/live.m3u8?token=abc');
        expect(favorite.status, LiveFavoriteStatus.live);
        expect(() => PureLiveDirectLinkSite().getDanmaku(), returnsNormally);
      },
    );
  });

  group('DouyinLivePlatformAdapter', () {
    test('imports a Douyin root live link as its fixed web RID', () async {
      const rawLink =
          'https://www.douyin.com/root/live/549201737274?anchor_id=2008169746277500';
      String? requestedWebRid;
      final adapter = DouyinLivePlatformAdapter(
        getRoomDetailForRecording: ({required platform, required roomId}) {
          fail('A root live URL must resolve by web RID');
        },
        getRoomDetailByWebRid: (webRid) async {
          requestedWebRid = webRid;
          return LiveRoom(
            platform: 'douyin',
            roomId: webRid,
            liveStatus: LiveStatus.live,
            title: 'Root live room',
          );
        },
      );

      expect(adapter.canResolve(rawLink), isTrue);
      final favorite = await adapter.resolveFavorite(rawLink);
      expect(requestedWebRid, '549201737274');
      expect(favorite.roomUrl, 'https://live.douyin.com/549201737274');
      expect(
        adapter.canResolve(
          'https://www.douyin.com.evil.test/root/live/549201737274',
        ),
        isFalse,
      );
    });

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
      expect(
        DouyinLivePlatformAdapter.roomIdFromUrl(
          'https://webcast.amemv.com/douyin/webcast/reflow/7703888993011714852?sec_user_id=MS4wLjABAAAAiAgcUI6SO0bmf_r0Lgx7LtALSyWoeITAOTInzISow0LXWMY1jmVZt1-Rvy8ZGIuP',
        ),
        '7703888993011714852',
      );
      expect(
        DouyinLivePlatformAdapter.roomIdFromUrl(
          'https://webcast.amemv.com.evil.test/douyin/webcast/reflow/7703888993011714852',
        ),
        isNull,
      );
    });

    test(
      'uses Pure Live recording room resolution before creating a favorite',
      () async {
        String? requestedRoomId;
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailByWebRid: (webRid) async {
            requestedRoomId = webRid;
            return LiveRoom(
              roomId: webRid,
              platform: 'douyin',
              title: 'Authorized live room',
              nick: 'Anchor',
              cover: 'https://img.test/cover.jpg',
              link: 'https://live.douyin.com/$webRid',
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

    test(
      'resolves a Douyin webcast share link and stores its canonical room URL',
      () async {
        String? requestedRoomId;
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailForRecording:
              ({required platform, required roomId}) async {
                requestedRoomId = roomId;
                return LiveRoom(
                  roomId: '106100309724',
                  platform: platform,
                  title: 'Shared live room',
                  nick: 'Anchor',
                  liveStatus: LiveStatus.live,
                );
              },
        );

        final favorite = await adapter.resolveFavorite(
          'https://webcast.amemv.com/douyin/webcast/reflow/7703888993011714852?sec_user_id=MS4wLjABAAAAiAgcUI6SO0bmf_r0Lgx7LtALSyWoeITAOTInzISow0LXWMY1jmVZt1-Rvy8ZGIuP',
        );

        expect(requestedRoomId, '7703888993011714852');
        expect(favorite.identityKey, 'douyin:106100309724');
        expect(favorite.roomUrl, 'https://live.douyin.com/106100309724');
        expect(favorite.title, 'Shared live room');
      },
    );

    test('keeps a verified offline room out of the live bucket', () async {
      final adapter = DouyinLivePlatformAdapter(
        getRoomDetailByWebRid: (webRid) async => LiveRoom(
          roomId: webRid,
          platform: 'douyin',
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

    test('refreshes a canonical 19-digit web room ID as a web RID', () async {
      const webRid = '7703888993011714852';
      String? requestedWebRid;
      final adapter = DouyinLivePlatformAdapter(
        getRoomDetailForRecording: ({required platform, required roomId}) {
          fail('A canonical live.douyin.com URL must not use reflow room_id');
        },
        getRoomDetailByWebRid: (roomId) async {
          requestedWebRid = roomId;
          return LiveRoom(
            roomId: roomId,
            platform: 'douyin',
            title: 'Refreshed room',
            liveStatus: LiveStatus.offline,
          );
        },
      );

      final refreshed = await adapter.refreshFavorite(
        LiveFavorite(
          platformId: 'douyin',
          roomId: webRid,
          roomUrl: 'https://live.douyin.com/$webRid',
        ),
      );

      expect(requestedWebRid, webRid);
      expect(refreshed.title, 'Refreshed room');
      expect(refreshed.status, LiveFavoriteStatus.offline);
    });

    test(
      'refreshes a saved room with a legacy URL using its room ID',
      () async {
        const webRid = '124915647724';
        String? requestedWebRid;
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailByWebRid: (roomId) async {
            requestedWebRid = roomId;
            return LiveRoom(
              roomId: roomId,
              platform: 'douyin',
              title: 'Refreshed room',
              liveStatus: LiveStatus.offline,
            );
          },
        );

        final refreshed = await adapter.refreshFavorite(
          LiveFavorite(
            platformId: 'douyin',
            roomId: webRid,
            roomUrl: 'https://www.douyin.com/user/legacy',
          ),
        );

        expect(requestedWebRid, webRid);
        expect(refreshed.roomUrl, 'https://live.douyin.com/$webRid');
        expect(refreshed.status, LiveFavoriteStatus.offline);
      },
    );

    test(
      'does not create a favorite when room status cannot be verified',
      () async {
        final adapter = DouyinLivePlatformAdapter(
          getRoomDetailByWebRid: (webRid) async => LiveRoom(
            roomId: webRid,
            platform: 'douyin',
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
              getRoomDetailByWebRid: (webRid) async => LiveRoom(
                roomId: webRid,
                platform: 'douyin',
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
