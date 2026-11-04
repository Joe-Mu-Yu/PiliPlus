import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/recorder_center/recorder_material_localizations.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pure_live/host/recording_i18n.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:PiliPlus/utils/page_utils.dart';

class RecorderCenterPage extends StatelessWidget {
  const RecorderCenterPage({super.key});

  @override
  Widget build(BuildContext context) => RecorderMaterialLocalizations(
    child: FutureBuilder<void>(
      future: _initializeRecordingUi(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SimpleScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SimpleScaffold(
            body: Center(child: Text('录制服务初始化失败')),
          );
        }
        return RecorderPage(
          onOpenRoom: (room) {
            final roomId = int.tryParse(room.roomId ?? '');
            if (room.platform?.trim().toLowerCase() == 'bilibili' &&
                roomId != null) {
              PageUtils.toLiveRoom(roomId);
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('当前暂不支持在 PiliPlus 中打开该平台直播间'),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _initializeRecordingUi() async {
    await RecordingI18n.initialize();
    setupPureLiveRecordingServices();
  }
}
