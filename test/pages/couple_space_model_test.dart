import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/common/widgets/image_viewer/gallery_viewer.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/pages/couple_space/couple_space_model.dart';
import 'package:PiliPlus/pages/couple_space/notification_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDirectory;

  setUpAll(() async {
    testDirectory = Directory.systemTemp.createTempSync(
      'couple-space-gallery-test-',
    );
    Hive.init(testDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    testDirectory.deleteSync(recursive: true);
  });

  group('小窝成员身份', () {
    test('成员映射缺失时不会继承另一成员的共享昵称', () {
      final payload = <String, dynamic>{
        'nickname': '小昱',
        'memberNames': <String, dynamic>{'uid-yu': '小昱'},
      };

      expect(
        coupleCurrentMemberName(
          payload: payload,
          userId: 'uid-yao',
          account: 'xiaoyao',
        ),
        'xiaoyao',
      );
    });

    test('旧相册动态从私有照片路径恢复真实发布者', () {
      final payload = <String, dynamic>{
        'memberNames': <String, dynamic>{
          'uid-yu': '小昱',
          'uid-yao': '小瑶',
        },
      };

      final moment = normalizeCoupleMoment({
        'photos': ['cloud:space-a/uid-yao/photo.jpg'],
        'caption': '旧动态',
      }, payload);

      expect(moment['authorId'], 'uid-yao');
      expect(moment['authorName'], '小瑶');
      expect(
        coupleEntryAuthorName(payload: payload, entry: moment),
        '小瑶',
      );
    });

    test('动态自身作者优先于照片路径并兼容旧评论署名', () {
      final payload = <String, dynamic>{
        'memberNames': <String, dynamic>{
          'uid-yu': '小昱',
          'uid-yao': '小瑶',
        },
      };

      final moment = normalizeCoupleMoment({
        'authorId': 'uid-yu',
        'authorName': '小昱',
        'photos': ['cloud:space-a/uid-yao/photo.jpg'],
        'comments': [
          {'author': '旧昵称', 'text': '收到'},
        ],
      }, payload);

      expect(moment['authorId'], 'uid-yu');
      expect(moment['authorName'], '小昱');
      expect((moment['comments'] as List).single['authorName'], '旧昵称');
    });

    test('心语评论固定记录当前成员 UID、昵称和 UTC 时间', () {
      final comment = createCoupleComment(
        id: 'comment-a',
        authorId: 'uid-yao',
        authorName: '小瑶',
        text: '  我也想你  ',
        createdAt: DateTime.parse('2026-11-09T20:30:00+08:00'),
      );

      expect(comment['authorId'], 'uid-yao');
      expect(comment['authorName'], '小瑶');
      expect(comment['text'], '我也想你');
      expect(comment['createdAt'], '2026-11-09T12:30:00.000Z');
    });
  });

  group('小窝动态照片模型', () {
    test('并发发布时合并本机动态并保留另一成员的最新动态', () {
      final merged = mergeCoupleMomentIntoPayload(
        latestPayload: {
          'albums': [
            {
              'id': 'moment-from-partner',
              'authorId': 'uid-partner',
              'photos': ['cloud:space/uid-partner/one.jpg'],
              'publishedAt': '2026-11-11T10:01:00Z',
            },
          ],
          'messages': [
            {'id': 'message-from-partner', 'text': '保留这条心语'},
          ],
        },
        moment: {
          'id': 'moment-from-me',
          'authorId': 'uid-me',
          'photos': ['cloud:space/uid-me/two.jpg'],
          'publishedAt': '2026-11-11T10:02:00Z',
        },
      );

      expect(
        (merged['albums'] as List).map((moment) => moment['id']),
        ['moment-from-me', 'moment-from-partner'],
      );
      expect((merged['messages'] as List).single['id'], 'message-from-partner');
    });

    test('重试合并相同动态不会重复添加', () {
      final moment = {
        'id': 'moment-same',
        'photos': ['cloud:space/uid-me/photo.jpg'],
      };
      final merged = mergeCoupleMomentIntoPayload(
        latestPayload: {
          'albums': [moment],
        },
        moment: moment,
      );

      expect((merged['albums'] as List), hasLength(1));
    });

    test('旧字符串照片保持兼容', () {
      final photos = coupleMomentPhotos({
        'photos': ['cloud:space-a/uid-yao/photo.jpg'],
      });

      expect(photos, [
        const CoupleSpacePhoto(
          imagePath: 'cloud:space-a/uid-yao/photo.jpg',
        ),
      ]);
      expect(photos.single.isLivePhoto, isFalse);
      expect(photos.single.toJson(), 'cloud:space-a/uid-yao/photo.jpg');
    });

    test('动态照片保留封面、伴随视频和尺寸', () {
      final photos = coupleMomentPhotos({
        'photos': [
          {
            'type': coupleSpaceLivePhotoType,
            'imagePath': 'cloud:space-a/uid-yao/photo.jpg',
            'videoPath': 'cloud:space-a/uid-yao/photo.mp4',
            'width': '1440',
            'height': 1080.0,
          },
        ],
      });

      expect(photos.single.isLivePhoto, isTrue);
      expect(photos.single.width, 1440);
      expect(photos.single.height, 1080);
      expect(photos.single.mediaPaths, [
        'cloud:space-a/uid-yao/photo.jpg',
        'cloud:space-a/uid-yao/photo.mp4',
      ]);
      expect(photos.single.toJson(), {
        'type': coupleSpaceLivePhotoType,
        'imagePath': 'cloud:space-a/uid-yao/photo.jpg',
        'videoPath': 'cloud:space-a/uid-yao/photo.mp4',
        'width': 1440,
        'height': 1080,
      });
    });

    test('动态照片封面路径可以恢复真实发布者', () {
      final moment = normalizeCoupleMoment(
        {
          'photos': [
            {
              'type': coupleSpaceLivePhotoType,
              'imagePath': 'cloud:space-a/uid-yao/photo.jpg',
              'videoPath': 'cloud:space-a/uid-yao/photo.mp4',
            },
          ],
        },
        {
          'memberNames': {'uid-yao': '小瑶'},
        },
      );

      expect(moment['authorId'], 'uid-yao');
      expect(moment['authorName'], '小瑶');
      expect((moment['photos'] as List).single, isA<Map>());
    });
  });

  group('小窝新消息通知', () {
    test('汇总对方新发布的相册动态、心语和评论', () {
      final previous = <String, dynamic>{
        'memberNames': {'uid-me': '我', 'uid-ta': 'TA'},
        'albums': [
          {
            'id': 'moment-old',
            'authorId': 'uid-me',
            'comments': <Map<String, dynamic>>[],
          },
        ],
        'messages': <Map<String, dynamic>>[],
      };
      final current = <String, dynamic>{
        'memberNames': {'uid-me': '我', 'uid-ta': 'TA'},
        'albums': [
          {
            'id': 'moment-new',
            'authorId': 'uid-ta',
            'photos': ['cloud:space/uid-ta/a.jpg', 'cloud:space/uid-ta/b.jpg'],
            'comments': <Map<String, dynamic>>[],
          },
          {
            'id': 'moment-old',
            'authorId': 'uid-me',
            'comments': [
              {
                'id': 'comment-new',
                'authorId': 'uid-ta',
                'text': '真好看',
              },
            ],
          },
        ],
        'messages': [
          {
            'id': 'message-new',
            'authorId': 'uid-ta',
            'authorName': 'TA',
            'type': 'text',
            'text': '晚上一起散步吧',
            'comments': <Map<String, dynamic>>[],
          },
        ],
      };

      final notification = coupleSpaceNotificationForChanges(
        previousPayload: previous,
        currentPayload: current,
        currentUserId: 'uid-me',
      );

      expect(notification, isNotNull);
      expect(notification!.count, 3);
      expect(notification.title, '小窝有 3 条新消息');
      expect(notification.body, 'TA 发布了2 张照片');
    });

    test('忽略自己新增的内容和没有新增内容的修订', () {
      final previous = <String, dynamic>{
        'albums': <Map<String, dynamic>>[],
        'messages': <Map<String, dynamic>>[],
      };
      final current = <String, dynamic>{
        'albums': [
          {
            'id': 'mine',
            'authorId': 'uid-me',
            'photos': ['local.jpg'],
          },
        ],
        'messages': <Map<String, dynamic>>[],
      };

      expect(
        coupleSpaceNotificationForChanges(
          previousPayload: previous,
          currentPayload: current,
          currentUserId: 'uid-me',
        ),
        isNull,
      );
      expect(
        coupleSpaceNotificationForChanges(
          previousPayload: current,
          currentPayload: current,
          currentUserId: 'uid-me',
        ),
        isNull,
      );
    });

    test('获得通知权限后把新消息交给 Android 系统通知桥接', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('test/couple-space-notifications');
      MethodCall? received;
      var permissionRequests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = CoupleSpaceNotificationService(
        channel: channel,
        requestPermission: () async {
          permissionRequests += 1;
          return true;
        },
      );

      expect(await service.prepare(), isTrue);
      final shown = await service.show(
        const CoupleSpaceActivityNotification(
          id: 'message:one',
          title: '小窝有新消息',
          body: 'TA：想你了',
          count: 1,
        ),
      );

      expect(shown, isTrue);
      expect(permissionRequests, 1);
      expect(received?.method, 'show');
      expect(received?.arguments, {
        'id': 'message:one',
        'title': '小窝有新消息',
        'body': 'TA：想你了',
        'count': 1,
      });
    });
  });

  testWidgets('相册预览可以左右滑动整组照片并更新页码', (tester) async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final first = File('${testDirectory.path}/first.png')
      ..writeAsBytesSync(imageBytes);
    final second = File('${testDirectory.path}/second.png')
      ..writeAsBytesSync(imageBytes);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: GalleryViewer(
            quality: 100,
            sources: [
              SourceModel(sourceType: SourceType.fileImage, url: first.path),
              SourceModel(sourceType: SourceType.fileImage, url: second.path),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    await tester.flingFrom(
      tester.getCenter(find.byType(GalleryViewer)),
      const Offset(-500, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  group('coupleTogetherDayNumber', () {
    test('起始日计为第一天并随自然日变化', () {
      expect(
        coupleTogetherDayNumber(
          DateTime(2026, 11, 7, 23, 50),
          DateTime(2026, 11, 7, 23, 59),
        ),
        1,
      );
      expect(
        coupleTogetherDayNumber(
          DateTime(2026, 11, 7, 23, 50),
          DateTime(2026, 11, 8, 0, 1),
        ),
        2,
      );
    });

    test('未来日期显示为尚未开始', () {
      expect(
        coupleTogetherDayNumber(DateTime(2026, 11, 8), DateTime(2026, 11, 7)),
        0,
      );
    });
  });

  group('coupleAnniversaryStatus', () {
    test('年度纪念日计算下一次到来日期', () {
      final status = coupleAnniversaryStatus({
        'title': '生日',
        'date': '2000-11-10T00:00:00.000',
        'type': 'birthday',
        'repeat': 'yearly',
      }, DateTime(2026, 11, 7));

      expect(status.label, '还有 3 天');
      expect(status.occurrence, DateTime.utc(2026, 11, 10));
    });

    test('年度 2 月 29 日在非闰年回落到月末', () {
      final status = coupleAnniversaryStatus({
        'title': '特别的一天',
        'date': '2024-02-29T00:00:00.000',
        'repeat': 'yearly',
      }, DateTime(2025, 2, 27));

      expect(status.occurrence, DateTime.utc(2025, 2, 28));
      expect(status.label, '还有 1 天');
    });

    test('一次性日期区分未来与已经过去', () {
      expect(
        coupleAnniversaryStatus({
          'title': '旅行',
          'date': '2026-11-09T00:00:00.000',
        }, DateTime(2026, 11, 7)).label,
        '还有 2 天',
      );
      expect(
        coupleAnniversaryStatus({
          'title': '相遇',
          'date': '2026-11-05T00:00:00.000',
        }, DateTime(2026, 11, 7)).label,
        '已过去 2 天',
      );
    });

    test('列表优先显示最近将到日期，再显示已经过去的日期', () {
      final sorted = sortCoupleAnniversaries([
        {'title': '旧旅行', 'date': '2026-10-01T00:00:00.000'},
        {'title': '明天', 'date': '2026-11-08T00:00:00.000'},
        {
          'title': '每年生日',
          'date': '2000-11-10T00:00:00.000',
          'type': 'birthday',
          'repeat': 'yearly',
        },
      ], DateTime(2026, 11, 7));

      expect(
        sorted.map((item) => item['title']),
        ['明天', '每年生日', '旧旅行'],
      );
    });
  });
}
