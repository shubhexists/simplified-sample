import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class AudioController {
  late AudioPlayer player;
  late AudioSession session;

  Future<void> init() async {
    session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    player = AudioPlayer();
  }

  Future<void> playAudio(Uri audioUri) async {
    await player.setAudioSource(
      AudioSource.uri(audioUri),
      initialPosition: Duration.zero,
    );
    await player.play();
  }

  Future<void> switchToInternalSpeaker() async {
    await session.configure(AudioSessionConfiguration.speech());
  }

  Future<void> switchToExternalSpeaker() async {
    await session.configure(AudioSessionConfiguration.music());
  }

  Future<void> dispose() async {
    await player.dispose();
  }
}
