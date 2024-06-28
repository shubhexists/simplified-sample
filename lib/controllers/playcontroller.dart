import 'package:audioplayers/audioplayers.dart';

class Player {
  String filename = '';
  String trackName = '';
  AudioPlayer player = AudioPlayer();
  bool playing = false;
  bool repeat = false;
  String currTimeString = '0:00:00';
  double currTime = 0;
  String totalDurationString = '0:00:00';
  double totalDuration = 0;
  DeviceFileSource? source;
  Function()? onCompletion;

  Player(this.filename);
  Future<void> setSource(String file) async {
    source = DeviceFileSource(file);
    filename = file;
  }

  void playMusic() {
    player.play(source as Source);
    player.onPlayerComplete.listen((event) {
      if (onCompletion != null) {
        onCompletion!();
      }
    });
  }

  void stopMusic() {
    player.stop();
  }

  void resetMusic() {
    player.seek(const Duration(seconds: 0));
    currTime = 0;
    currTimeString = const Duration(seconds: 0).toString().split('.').first;
  }

  double parseDuration(String s) {
    double hours = 0;
    double minutes = 0;
    double seconds;
    List<String> parts = s.split(':');
    if (parts.length > 2) {
      hours = double.parse(parts[parts.length - 3]) * 120;
    }
    if (parts.length > 1) {
      minutes = double.parse(parts[parts.length - 2]) * 60;
    }
    seconds = (double.parse(parts[parts.length - 1]));
    return hours + minutes + seconds;
  }
}
