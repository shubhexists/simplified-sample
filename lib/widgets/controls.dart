// ignore_for_file: unused_local_variable, library_prefixes, unused_field, unused_element
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_example/pages/connect.dart';
import 'package:livekit_example/pages/room.dart';
import 'package:livekit_example/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class ControlsWidget extends StatefulWidget {
  final Room room;
  final LocalParticipant participant;
  final int rad;
  final String roomName;

  const ControlsWidget(
    this.rad,
    this.room,
    this.participant,
    this.roomName, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ControlsWidgetState();
}

class _ControlsWidgetState extends State<ControlsWidget> {
  CameraPosition position = CameraPosition.front;
  List<MediaDevice>? _audioInputs;
  List<MediaDevice>? _audioOutputs;
  List<MediaDevice>? _videoInputs;
  StreamSubscription? _subscription;

  final record = Record();

  @override
  void initState() {
    super.initState();
    if (role != 'User') {
      _enableAudio();
    }
    participant.addListener(_onChange);
    _subscription = Hardware.instance.onDeviceChange.stream
        .listen((List<MediaDevice> devices) {
      _loadDevices(devices);
    });
    Timer(const Duration(seconds: 10), () {
      _disableVideo();
    });
    Hardware.instance.enumerateDevices().then(_loadDevices);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    participant.removeListener(_onChange);
    super.dispose();
  }

  LocalParticipant get participant => widget.participant;

  void _loadDevices(List<MediaDevice> devices) async {
    _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
    _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();
    _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
    setState(() {});
  }

  void _onChange() {
    setState(() {});
  }

  bool get isMuted => participant.isMuted;

  _disableAudio() async {
    await participant.setMicrophoneEnabled(false);
    setState(() {
      boxcolor = false;
    });
  }

  Future<void> _enableAudio() async {
    await participant.setMicrophoneEnabled(true);
    setState(() {
      boxcolor = true;
    });
  }

  void _disableVideo() async {
    await participant.setCameraEnabled(false);
  }

  setIsMuted() {
    var url = Uri.parse(
        'https://backend.zoomtod.com/api/user/setIsMute/${userIdController.text.toString()}');
    var response = http.put(
      url,
    );
  }

  startRecording() async {
    Directory? appDocDirectory = await getExternalStorageDirectory();
    String dir = appDocDirectory!.path + '/Recordings';
    Directory directory = Directory(dir);
    if (directory.existsSync()) {
      print('Directory Exists');
    } else {
      directory.createSync(recursive: true);
    }
    DateTime now = DateTime.now();
    String formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(now).replaceAll(':', '-');
    String path = '$dir/recording$formattedDate.m4a';
    if (await record.hasPermission()) {
      await record.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );
      print('Recording Started');
    }
  }

  stopRecording() async {
    await record.stop();
    print('Recording Stopped');
  }

  setIsSpeaking() {
    var url = Uri.parse(
        'https://backend.zoomtod.com/api/user/setIsSpeaking/${userIdController.text.toString()}');
    var response = http.put(
      url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxColorProvider = Provider.of<BoxColorProvider>(context);

    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          print('tapped');
        },
        onTapDown: (_) async {
          await HapticFeedback.vibrate();
          final PermissionStatus permission =
              await Permission.microphone.status;
          if (permission == PermissionStatus.granted) {
            if (role == 'User') {
              if (participant.permissions.canPublish) {
                await startRecording();
                socket.emit('buttonPress', {
                  'user': nameFinal.toString(),
                  'roomId': widget.roomName.toString()
                });
              }
            }
            await setIsSpeaking();
            await _enableAudio();
          } else {
            final Map<Permission, PermissionStatus> permissionStatus =
                await [Permission.microphone].request();
          }
        },
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 500))
              .then((value) async {
            if (role == 'User') {
              socket.emit('buttonRelease', {
                'user': nameFinal.toString(),
                'roomId': widget.roomName.toString()
              });
              await _disableAudio();
              await stopRecording();
              await setIsMuted();
            }
          });
        },
        onTapCancel: () async {
          await Future.delayed(const Duration(milliseconds: 500))
              .then((value) async {
            if (role == 'User') {
              socket.emit('buttonRelease', {
                'user': nameFinal.toString(),
                'roomId': widget.roomName.toString()
              });
              await _disableAudio();
              await stopRecording();
              await setIsMuted();
            }
          });
        },
        child: Container(
          width: widget.rad.toDouble(),
          height: widget.rad.toDouble(),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMuted ? Colors.black : Colors.green[700],
            border: Border.all(
              color: const Color.fromARGB(255, 253, 216, 53),
              width: 9,
            ),
          ),
          child: Center(
              child: Icon(
            Icons.mic,
            color: Colors.white,
            size: (role == 'User') ? 95 : 90,
          )),
        ),
      ),
    );
  }
}
