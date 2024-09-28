import 'package:get/get.dart';

enum PlayerStatus { completed, playing, paused, disabled }

class PlPlayerStatus {
  Rx<PlayerStatus> status = Rx(PlayerStatus.paused);

  bool get playing {
    return status.value == PlayerStatus.playing;
  }

  bool get paused {
    return status.value == PlayerStatus.paused;
  }

  bool get completed {
    return status.value == PlayerStatus.completed;
  }

  bool get disabled {
    return status.value == PlayerStatus.disabled;
  }
}
