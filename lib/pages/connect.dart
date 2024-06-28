// ignore_for_file: prefer_typing_uninitialized_variables, unused_field, unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/widgets/text_field.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../exts.dart';
import '../utils/AudioController.dart';
import 'room.dart';

final userIdController = TextEditingController();
var role;
var roomName;
var nameFinal;

class ConnectPage extends StatefulWidget {
  //
  const ConnectPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  //
  static const _storeKeyUri = 'uri';
  static const _storeKeyToken = 'token';
  static const _storeKeySimulcast = 'simulcast';
  static const _storeKeyAdaptiveStream = 'adaptive-stream';
  static const _storeKeyDynacast = 'dynacast';
  static const _storeKeyFastConnect = 'fast-connect';
  final _uriCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final roomController = TextEditingController();

  final audioController = AudioController();

  final bool _simulcast = true;
  final bool _adaptiveStream = true;
  final bool _dynacast = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    audioController.init();
  }

// Handle call received
  void handleCallReceived() {
    audioController.switchToInternalSpeaker();
  }

// Handle call ended
  void handleCallEnded() {
    audioController.switchToExternalSpeaker();
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _tokenCtrl.dispose();
    audioController.dispose();
    super.dispose();
  }

  Future _getToken() async {
    var url = Uri.parse('https://backend.zoomtod.com/api/livekit/usertoken');
    var response = await http.post(
      url,
      body: jsonEncode({
        'identity': nameFinal.toString(),
        'room': roomController.text.toString(),
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    print('Response body: ${response.body}');
    _tokenCtrl.text = json.decode(response.body)['token'].toString();
  }

  _changeState() {
    var url = Uri.parse(
        'https://backend.zoomtod.com/api/user/changeStatusTrue/${userIdController.text.toString()}');
    var response = http.put(
      url,
    );
  }

  getParticipantName() async {
    var response = await http.get(
      Uri.parse(
          'https://backend.zoomtod.com/api/admin/getuser/${userIdController.text.toString()}'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    var username = json.decode(response.body)['user']['name'];
    print(username);
    return username;
  }

  handleDeviceInfo(id) async {
    var url =
        Uri.parse('https://backend.zoomtod.com/api/user/setDeviceInfo/${id}');
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      await deviceInfoPlugin.androidInfo.then((androidInfo) async {
        var response = await http.put(
          url,
          body: jsonEncode({
            'deviceInfo': androidInfo.model.toString(),
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      });
    } else if (Platform.isIOS) {
      await deviceInfoPlugin.iosInfo.then((iosInfo) async {
        var response = await http.put(
          url,
          body: jsonEncode({
            'deviceInfo': iosInfo.name.toString(),
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      });
    }
  }

  Future _join() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    await deviceInfoPlugin.androidInfo.then((androidinfo) async {
      var url = Uri.parse('https://backend.zoomtod.com/api/auth/login');
      var response = await http.post(
        url,
        body: jsonEncode({
          'username': userIdController.text.toString(),
          'password': _passwordCtrl.text.toString(),
          'device': androidinfo.model.toString(),
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        roomController.text = json.decode(response.body)['roomId'].toString();
        nameFinal = await getParticipantName();
        role = json.decode(response.body)['role'].toString();
        roomName = json.decode(response.body)['roomId'].toString();
        print(roomName);
        await _getToken();
      } else {
        print('error');
      }
    });
  }

  handleLastLogTime(id) {
    print(id);
    var url =
        Uri.parse('https://backend.zoomtod.com/api/user/changeLogTime/${id}');
    DateTime now = DateTime.now();
    String formatter = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    print(formatter);
    var response = http.post(
      url,
      body: jsonEncode({
        'logTime': formatter.toString(),
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }

  Future<void> _connect(BuildContext ctx) async {
    try {
      setState(() {
        _busy = true;
      });
      await _join();
      if (_tokenCtrl.text != '') {
        print('Connecting with url: ${_uriCtrl.text}, '
            'token: ${_tokenCtrl.text}...');
        await _changeState();
        await getParticipantName();
        await handleLastLogTime(userIdController.text.toString());
        await handleDeviceInfo(userIdController.text.toString());
        final room = Room();
        final listener = room.createListener();
        await room.connect(
          _uriCtrl.text,
          _tokenCtrl.text,
          roomOptions: RoomOptions(
            adaptiveStream: _adaptiveStream,
            dynacast: _dynacast,
            defaultVideoPublishOptions: VideoPublishOptions(
              simulcast: _simulcast,
            ),
            defaultScreenShareCaptureOptions:
                const ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
          ),
          fastConnectOptions: null,
        );
        await Navigator.push<void>(
          ctx,
          MaterialPageRoute(
              builder: (_) =>
                  RoomPage(room, roomController.text.toString(), listener)),
        );
      } else {
        const snackBar = SnackBar(
          content: Text('Please enter valid credentials'),
          duration: Duration(seconds: 3),
        );
        ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
      }
    } catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog(error);
    } finally {
      setState(() {
        _busy = false;
      });
    }
    _tokenCtrl.text = '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          color: const Color.fromARGB(255, 218, 197, 141),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(
                        'ZOOMTOD',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inknutAntiqua(
                          fontSize: 40,
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'UserId',
                      ctrl: userIdController,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: LKTextField(
                      label: 'Password',
                      ctrl: _passwordCtrl,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                          const Color.fromARGB(255, 179, 77, 223)),
                    ),
                    onPressed: _busy ? null : () => _connect(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('CONNECT',
                              style:
                                  TextStyle(fontSize: 15, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
