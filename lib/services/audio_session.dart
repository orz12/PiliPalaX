import 'package:audio_session/audio_session.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class AudioSessionHandler {
  late AudioSession session;
  bool _playInterrupted = false;

  Future<bool> setActive(bool active) async {
    return await session.setActive(active);
  }

  AudioSessionHandler() {
    initSession().then((_) {
      setActive(true);
    });
  }

  Future<void> initSession() async {
    session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.devicesChangedEventStream.listen((AudioDevicesChangedEvent event) =>
        SmartDialog.showNotify(
            alignment: Alignment.centerLeft,
            msg: '设备变化, ${event.devicesAdded}, ${event.devicesRemoved}',
            notifyType: NotifyType.alert));
    session.interruptionEventStream
        .listen((AudioInterruptionEvent event) async {
      final playerStatus = PlPlayerController.getPlayerStatusIfExists();
      // final player = PlPlayerController.getInstance();
      if (event.begin) {
        if (playerStatus != PlayerStatus.playing) return;
        // if (!player.playerStatus.playing) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
                (PlPlayerController.getVolumeIfExists() ?? 0) * 0.5);
            // player.setVolume(player.volume.value * 0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            SmartDialog.showNotify(
                msg: '音频播放被中断, ${event.type}', notifyType: NotifyType.error);
            PlPlayerController.pauseIfExists(isInterrupt: true);
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
                (PlPlayerController.getVolumeIfExists() ?? 0) * 2);
            // player.setVolume(player.volume.value * 2);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_playInterrupted) PlPlayerController.playIfExists();
            break;
        }
        _playInterrupted = false;
      }
    });
    session.configurationStream.listen((event) {
      SmartDialog.showNotify(
          msg: 'configurationStream, $event', notifyType: NotifyType.failure);
    });
    // 耳机拔出暂停
    session.becomingNoisyEventStream.listen((_) {
      SmartDialog.showNotify(
          msg: '音频播放被中断, noisy', notifyType: NotifyType.error);
      PlPlayerController.pauseIfExists();
      // final player = PlPlayerController.getInstance();
      // if (player.playerStatus.playing) {
      //   player.pause();
      // }
    });
  }
}
