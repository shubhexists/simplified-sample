// ignore_for_file: non_constant_identifier_names, unused_local_variable, prefer_typing_uninitialized_variables, unused_element, avoid_unnecessary_containers, unused_field, library_prefixes

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/pages/changePass.dart';
import 'package:livekit_example/pages/connect.dart';
import 'package:livekit_example/pages/recordingScreen.dart';
import 'package:lottie/lottie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../exts.dart';
import '../widgets/controls.dart';
import '../widgets/participant.dart';
import 'package:http/http.dart' as http;
import '../widgets/participant_info.dart';

var boxcolor = false;


class RoomPage extends StatefulWidget {
  final Room room;
  final String RoomName;
  final EventsListener<RoomEvent> listener;

  const RoomPage(
    this.room,
    this.RoomName,
    this.listener, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  List<ParticipantTrack> participantTracks = [];
  List<Widget> participantWidgets = [];
  String message = '';
  List<MediaDevice>? _audioInputs;
  var adminNameofthatRoom;
  List<MediaDevice>? _audioOutputs;
  List<MediaDevice>? _videoInputs;
  StreamSubscription? _subscription;
  bool isRecording = false;
  Timer? periodicTimer;
  bool muteTapped = false;
  bool logoutTapped = false;
  bool participantMute = false;
  EventsListener<RoomEvent> get _listener => widget.listener;
  bool get fastConnection => widget.room.engine.fastConnectOptions != null;

  @override
  void initState() {
    print('RoomPage initState');
    super.initState();
    WakelockPlus.enable();
    widget.room.addListener(_onRoomDidUpdate);
    _setAdminName();
    _setUpListeners();
    _sortParticipants();
    periodicTimer = periodic();
    _subscription = Hardware.instance.onDeviceChange.stream
        .listen((List<MediaDevice> devices) {
      _loadDevices(devices);
    });
    WidgetsBindingCompatible.instance?.addPostFrameCallback((_) {
      if (!fastConnection) {
        _askPublish();
      }
    });
    Hardware.instance.enumerateDevices().then(_loadDevices);
  }

  @override
  void dispose() {
    (() async {
      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
      periodicTimer?.cancel();
      await _subscription?.cancel();
    })();

    super.dispose();
  }

  void _loadDevices(List<MediaDevice> devices) async {
    _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
    _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();
    _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
    setState(() {});
  }

  fetchNameofAdmin() async {
    var response = await http.get(Uri.parse(
        'https://backend.zoomtod.com/api/user/getAdminFromRoomId/${widget.RoomName.toString()}'));
    var data = json.decode(response.body)['admin']['name'].toString();
    print(data);
    if (adminNameofthatRoom != data) {
      adminNameofthatRoom = data;
      setState(() {
        adminNameofthatRoom = data;
      });
    }
  }

  _setAdminName() async {
    var response = await http.get(Uri.parse(
        'https://backend.zoomtod.com/api/user/getAdminFromRoomId/${widget.RoomName.toString()}'));
    var data = json.decode(response.body)['admin']['name'].toString();
    setState(() {
      adminNameofthatRoom = data;
    });
  }

  getLivekitToken() async {
    var url = Uri.parse('https://backend.zoomtod.com/api/livekit/adminToken');
    var response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        {
          'identity': widget.RoomName.toString(),
          'room': widget.RoomName.toString(),
        },
      ),
    );
    var token = json.decode(response.body)['token'].toString();
    return token;
  }

  handleEndMeeting() async {
    var token = await getLivekitToken();
    print(token);
    var data = await handleListParticipants();
    for (var i in data) {
      if (i['identity'] != widget.RoomName.toString() &&
          i['identity'] != null) {
        var resp = await http.get(Uri.parse(
            'https://backend.zoomtod.com/api/admin/getIdFromName/${i['identity'].toString()}'));
        var id = json.decode(resp.body)['username'].toString();
        print(id);
        await http.put(Uri.parse(
            'https://backend.zoomtod.com/api/user/setUserMuteOffDb/${id}'));
      }
    }
    await _handleHostOutOfRoom(widget.RoomName.toString());
    var response = await http.post(
      Uri.parse(
          'https://livekit.zoomtod.com/twirp/livekit.RoomService/DeleteRoom'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(
        {
          'room': widget.RoomName.toString(),
        },
      ),
    );
  }

  _handleHostOutOfRoom(room) async {
    var url = Uri.parse(
        'https://backend.zoomtod.com/api/admin/setHostOutRoom/${room.toString()}');
    var response = await http.put(
      url,
    );
  }

  periodic() {
    const duration = Duration(seconds: 20);
    return Timer.periodic(duration, (Timer t) async {
      fetchNameofAdmin();
    });
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((event) async {
      if (event.reason != null) {
        print('Room disconnected: reason => ${event.reason}');
      }
      WidgetsBindingCompatible.instance
          ?.addPostFrameCallback((timeStamp) => Navigator.pop(context));
    })
    ..on<RoomRecordingStatusChanged>((event) {
      context.showRecordingStatusChangedDialog(event.activeRecording);
    })
    ..on<LocalTrackPublishedEvent>((_) => _sortParticipants())
    ..on<LocalTrackUnpublishedEvent>((_) => _sortParticipants())
    ..on<DataReceivedEvent>((event) {
      String decoded = 'Failed to decode';
      try {
        decoded = utf8.decode(event.data);
      } catch (_) {
        print('Failed to decode: $_');
      }
      context.showDataReceivedDialog(decoded);
    });

  void _askPublish() async {
    try {
      await widget.room.localParticipant?.setCameraEnabled(false);
    } catch (error) {
      print('could not publish video: $error');
      await context.showErrorDialog(error);
    }
    try {
      if (role == 'User') {
        await widget.room.localParticipant?.setMicrophoneEnabled(false);
      } else if (role == 'Host') {
        await widget.room.localParticipant?.setMicrophoneEnabled(true);
      }
    } catch (error) {
      print('could not publish audio: $error');
      await context.showErrorDialog(error);
    }
  }

  void _onRoomDidUpdate() {
    _sortParticipants();
  }

  handleListParticipants() async {
    var token = await getLivekitToken();
    print(token);
    var response = await http.post(
      Uri.parse(
          'https://livekit.zoomtod.com/twirp/livekit.RoomService/ListParticipants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(
        {
          'room': widget.RoomName.toString(),
        },
      ),
    );
    var data = json.decode(response.body)['participants'];
    return data;
  }

  void _sortParticipants() async {
    List<ParticipantTrack> userMediaTracks = [];
    List<ParticipantTrack> screenTracks = [];
    for (var participant in widget.room.participants.values) {
      userMediaTracks.add(ParticipantTrack(
          participant: participant, videoTrack: null, isScreenShare: false));
    }
    setState(() {
      participantTracks = [...userMediaTracks];
      participantWidgets = participantTracks.map((participantTrack) {
        if (participantTrack.participant.identity.isNotEmpty) {
          return ParticipantWidget.widgetFor(participantTrack);
        } else {
          return Container();
        }
      }).toList();
    });
  }

  handleMuteAllParticipants() async {
    var data = await handleListParticipants();
    var token = await getLivekitToken();
    for (var i in data) {
      if (i['identity'] != widget.RoomName.toString()) {
        var response = await http.post(
          Uri.parse(
              'https://livekit.zoomtod.com/twirp/livekit.RoomService/UpdateParticipant'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode(
            {
              'room': widget.RoomName.toString(),
              'identity': i['identity'].toString(),
              'permission': {
                'can_publish': false,
                'can_subscribe': false,
                'can_publish_data': false,
              }
            },
          ),
        );
        var resp = await http.get(Uri.parse(
            'https://backend.zoomtod.com/api/admin/getIdFromName/${i['identity'].toString()}'));
        var id = json.decode(resp.body)['username'].toString();
        await http.put(Uri.parse(
            'https://backend.zoomtod.com/api/user/setUserMuteOnDb/${id}'));
        print("done for ${i['identity']}");
      }
    }
    print('Done');
  }

  handleUnMuteAllParticipants() async {
    var data = await handleListParticipants();
    var token = await getLivekitToken();
    for (var i in data) {
      if (i['identity'] != widget.RoomName.toString()) {
        var response = await http.post(
          Uri.parse(
              'https://livekit.zoomtod.com/twirp/livekit.RoomService/UpdateParticipant'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode(
            {
              'room': widget.RoomName.toString(),
              'identity': i['identity'].toString(),
              'permission': {
                'can_publish': true,
                'can_subscribe': true,
                'can_publish_data': true,
              }
            },
          ),
        );
        var resp = await http.get(Uri.parse(
            'https://backend.zoomtod.com/api/admin/getIdFromName/${i['identity'].toString()}'));
        var id = json.decode(resp.body)['username'].toString();
        await http.put(Uri.parse(
            'https://backend.zoomtod.com/api/user/setUserMuteOffDb/${id.toString()}'));
        setState(() {});
        print("done for ${i['identity']}");
      }
    }
    print('Done');
  }

  handleMuteParticipantUser(a, id) async {
    if (widget.room.localParticipant!.permissions.canPublish) {
      var token = await getLivekitToken();
      var response = await http.post(
        Uri.parse(
            'https://livekit.zoomtod.com/twirp/livekit.RoomService/UpdateParticipant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(
          {
            'room': roomName.toString(),
            'identity': a.toString(),
            'permission': {
              'can_publish': true,
              'can_subscribe': false,
              'can_publish_data': true,
            }
          },
        ),
      );
      await http.put(Uri.parse(
          'https://backend.zoomtod.com/api/user/setUserMuteOnDb/${id}'));
      setState(() {
        participantMute = true;
      });
      print('done for ${a.toString()}');
    }
  }

  handleUnMuteParticipantUser(a, id) async {
    if (widget.room.localParticipant!.permissions.canPublish) {
      var token = await getLivekitToken();
      var response = await http.post(
        Uri.parse(
            'https://livekit.zoomtod.com/twirp/livekit.RoomService/UpdateParticipant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(
          {
            'room': roomName.toString(),
            'identity': a.toString(),
            'permission': {
              'can_publish': true,
              'can_subscribe': true,
              'can_publish_data': true,
            }
          },
        ),
      );
      await http.put(Uri.parse(
          'https://backend.zoomtod.com/api/user/setUserMuteOffDb/${id.toString()}'));
      setState(() {
        participantMute = false;
      });
      print('done for ${a.toString()}');
    }
  }

  void _onTapDisconnect() async {
    final result = await context.showDisconnectDialog();
    if (result == true) {
      await widget.room.disconnect();
    }
  }

  void _selectAudioOutput(MediaDevice device) async {
    await widget.room.setAudioOutputDevice(device);
    setState(() {});
  }

  handleLogoutAll() async {
    var data = await handleListParticipants();
    var token = await getLivekitToken();
    for (var i in data) {
      if (i['identity'] != widget.RoomName.toString()) {
        var response = await http.post(
          Uri.parse(
              'https://livekit.zoomtod.com/twirp/livekit.RoomService/RemoveParticipant'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode(
            {
              'room': widget.RoomName.toString(),
              'identity': i['identity'].toString(),
            },
          ),
        );
        var resp = await http.get(Uri.parse(
            'https://backend.zoomtod.com/api/admin/getIdFromName/${i['identity'].toString()}'));
        var id = json.decode(resp.body)['username'].toString();
        await http.put(Uri.parse(
            'https://backend.zoomtod.com/api/user/setUserMuteOffDb/${id.toString()}'));
        print("done for ${i['identity']}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: (role == 'User')
          ? Scaffold(
              body: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xff4600fe),
                    padding: EdgeInsets.only(top: height * 0.015),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Text(
                            'User: ${userIdController.text}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: height * 0.01),
                          Lottie.asset('images/mic_lottie.json',
                              height: height * 0.2),
                          SizedBox(height: height * 0.01),
                          Text(
                            adminNameofthatRoom.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(top: height * 0.015),
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          colors: [Color(0xffdcc2f4), Color(0xffb786f3)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              InkWell(
                                onTap: () async {
                                  if (participantMute) {
                                    await handleUnMuteParticipantUser(
                                        nameFinal.toString(),
                                        userIdController.text.toString());
                                  } else {
                                    await handleMuteParticipantUser(
                                        nameFinal.toString(),
                                        userIdController.text.toString());
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  height: 85,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          color: participantMute
                                              ? Colors.red
                                              : Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Icon(
                                          participantMute
                                              ? Icons.volume_off
                                              : Icons.volume_up,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Speaker',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ChangePass(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  height: 85,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Password',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FileListWidget(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  height: 85,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.audio_file_outlined,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Recording',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  _onTapDisconnect();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  height: 85,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.power_settings_new_outlined,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Exit',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.room.localParticipant != null)
                            const Spacer(),
                          const Text(
                            'Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.room.localParticipant != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: ControlsWidget(
                                (height * 0.3).toInt(),
                                widget.room,
                                widget.room.localParticipant!,
                                widget.RoomName,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (message.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      height: 60,
                      color: const Color(0xff475E69),
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Scaffold(
              appBar: AppBar(
                elevation: 0,
                backgroundColor: const Color(0xff4600fe),
                title: Text(
                  'Host: ${widget.RoomName}',
                  style: const TextStyle(color: Colors.white),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    height: 40,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.red[400],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        await _handleHostOutOfRoom(
                            userIdController.text.toString());
                        await handleEndMeeting();
                      },
                      icon: const Icon(Icons.power_settings_new_outlined),
                    ),
                  ),
                ],
                centerTitle: true,
                automaticallyImplyLeading: false,
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.67,
                      child: GridView(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          crossAxisCount: 4,
                        ),
                        children: participantWidgets,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    // color: const Color(0xff4600fe),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black38)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  const Color.fromARGB(255, 220, 213, 6)),
                            ),
                            onPressed: () async {
                              await handleLogoutAll();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Logout All',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              ),
                            )),
                        if (widget.room.localParticipant != null)
                          ControlsWidget(120, widget.room,
                              widget.room.localParticipant!, widget.RoomName),
                        Column(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            Colors.blue[300]!),
                                  ),
                                  onPressed: () async {
                                    await handleMuteAllParticipants();
                                    setState(() {
                                      muteTapped = true;
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Mute All',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 100,
                              child: TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            Colors.blue[300]!),
                                  ),
                                  onPressed: () async {
                                    await handleUnMuteAllParticipants();
                                    setState(() {
                                      muteTapped = false;
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Unmute All',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave the meeting?'),
            content: const Text('Are you sure you want to leave the meeting?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.room.disconnect();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }
}
