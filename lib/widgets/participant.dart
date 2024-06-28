// ignore_for_file: avoid_init_to_null, unused_local_variable, prefer_typing_uninitialized_variables, unnecessary_cast, sdk_version_since, library_prefixes, unnecessary_null_comparison
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as LC;
import 'package:livekit_example/pages/connect.dart';
import 'package:livekit_example/pages/room.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'participant_info.dart';

const backendUrl ='https://backend.zoomtod.com/api';

final IO.Socket socket1 = IO.io('http://13.235.100.219:5000', <String, dynamic>{
  'autoConnect': false,
  'transports': ['websocket'],
});

abstract class ParticipantWidget extends StatefulWidget {
  static ParticipantWidget widgetFor(ParticipantTrack participantTrack) {
    if (participantTrack.participant is LC.LocalParticipant) {
      return LocalParticipantWidget(
          participantTrack.participant as LC.LocalParticipant,
          participantTrack.videoTrack,
          participantTrack.isScreenShare);
    } else if (participantTrack.participant is LC.RemoteParticipant) {
      return RemoteParticipantWidget(
          participantTrack.participant as LC.RemoteParticipant,
          participantTrack.videoTrack,
          participantTrack.isScreenShare);
    }
    throw UnimplementedError('Unknown participant type');
  }

  abstract final LC.Participant participant;
  abstract final LC.VideoTrack? videoTrack;
  abstract final bool isScreenShare;
  final LC.VideoQuality quality;

  const ParticipantWidget({
    this.quality = LC.VideoQuality.MEDIUM,
    Key? key,
  }) : super(key: key);
}

class LocalParticipantWidget extends ParticipantWidget {
  @override
  final LC.LocalParticipant participant;
  @override
  final LC.VideoTrack? videoTrack;
  @override
  final bool isScreenShare;

  const LocalParticipantWidget(
    this.participant,
    this.videoTrack,
    this.isScreenShare, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LocalParticipantWidgetState();
}

class RemoteParticipantWidget extends ParticipantWidget {
  @override
  final LC.RemoteParticipant participant;
  @override
  final LC.VideoTrack? videoTrack;
  @override
  final bool isScreenShare;

  const RemoteParticipantWidget(
    this.participant,
    this.videoTrack,
    this.isScreenShare, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RemoteParticipantWidgetState();
}

abstract class _ParticipantWidgetState<T extends ParticipantWidget>
    extends State<T> {
  LC.VideoTrack? activeVideoTrack = null;
  LC.TrackPublication? get videoPublication;
  LC.TrackPublication? get firstAudioPublication;
  late final Future<String?> myFuture = getParticipantName();
  var color = Colors.green;
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      print('init state called');
      getParticipantName();
      getIdFromName();
      print('Connection established');
      socket.on('buttonPress', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            if (widget.participant.permissions.canSubscribe) {
              setState(() {
                color = Colors.red;
              });
            }
          }
        }
      });
      socket.on('buttonRelease', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            if (widget.participant.permissions.canSubscribe) {
              setState(() {
                color = Colors.green;
              });
            }
          }
        }
      });
      socket.on('mutedUser', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            setState(() {
              color = Colors.yellow;
            });
          }
        }
      });
      socket.on('unmutedUser', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            setState(() {
              color = Colors.green;
            });
          }
        }
      });
      widget.participant.addListener(_onParticipantChanged);
      _onParticipantChanged();
    });
    super.initState();
  }

  String userId = '';
  void getIdFromName() async {
    String name = widget.participant.identity.toString();
    var resp = await http.get(
        Uri.parse('$backendUrl/admin/getIdFromName/$name'));
    userId = json.decode(resp.body)['username'].toString();
    setState(() {});
  }

  @override
  void dispose() {
    socket1.disconnect();
    socket1.dispose();
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    oldWidget.participant.removeListener(_onParticipantChanged);
    getIdFromName();
    widget.participant.addListener(_onParticipantChanged);
    getParticipantName();
    _onParticipantChanged();
    super.didUpdateWidget(oldWidget);
  }

  void _onParticipantChanged() => setState(() {});
  getLivekitToken() async {
    var url = Uri.parse('$backendUrl/livekit/adminToken');
    var response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        {
          'identity': roomName.toString(),
          'room': roomName.toString(),
        },
      ),
    );
    var token = json.decode(response.body)['token'].toString();
    return token;
  }

  handleMuteParticipant(a) async {
    var resp = await http.get(Uri.parse(
        '$backendUrl/admin/getIdFromName/${a.toString()}'));
    var id = json.decode(resp.body)['username'].toString();
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
            'can_publish': false,
            'can_subscribe': false,
            'can_publish_data': false,
          }
        },
      ),
    );
    await http.put(
        Uri.parse('$backendUrl/user/setUserMuteOnDb/$id'));
    socket.emit('mutedUser',
        {'user': a.toString(), 'muted': true, 'roomId': roomName.toString()});
    print('done for ${a.toString()}');
  }

  handleUnMuteParticipant(a) async {
    var resp = await http.get(Uri.parse(
        '$backendUrl/admin/getIdFromName/${a.toString()}'));
    var id = json.decode(resp.body)['username'].toString();
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
    await http.put(
        Uri.parse('$backendUrl/user/setUserMuteOffDb/$id'));
    socket.emit('unmutedUser',
        {'user': a.toString(), 'unmuted': true, 'roomId': roomName.toString()});
    print('done for ${a.toString()}');
  }

  Future<String?> getParticipantName() async {
    socket1.connect();
    socket1.onConnect((_) async {
      print('Connection established');
      socket1.on('buttonPress', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            if (widget.participant.permissions.canSubscribe) {
              setState(() {
                color = Colors.red;
              });
            }
          }
        }
      });

      socket1.on('buttonRelease', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            if (widget.participant.permissions.canSubscribe) {
              setState(() {
                color = Colors.green;
              });
            }
          }
        }
      });

      socket1.on('mutedUser', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            setState(() {
              color = Colors.yellow;
            });
          }
        }
      });
      socket1.on('unmutedUser', (data) {
        print(data);
        if (data['user'] == widget.participant.identity) {
          if (data['roomId'] == roomName) {
            setState(() {
              color = Colors.green;
            });
          }
        }
      });
    });
    socket1.onDisconnect((_) => print('Connection Disconnection'));
    socket1.onConnectError((err) => print(err));
    socket1.onError((err) => print(err));
    return 'Hello';
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder<String?>(
      future: myFuture,
      builder: (context, snapshot) {
        return InkWell(
          onTap: () async {
            if (widget.participant.permissions.canSubscribe) {
              await handleMuteParticipant(
                  widget.participant.identity.toString());
              print(
                  'The Participant ${widget.participant.identity} is now unmuted');
            } else {
              await handleUnMuteParticipant(
                  widget.participant.identity.toString());
              print(
                  'The Participant ${widget.participant.identity} is now muted');
            }
          },
          child: Container(
            height: 100,
            width: 200,
            foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: widget.participant.isSpeaking && !widget.isScreenShare
                    ? Border.all(
                        width: 5,
                        color: const Color(0xFF5A8BFF),
                      )
                    : null),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8), color: widget.participant.isMuted? color : Colors.red),
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userId,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.participant.identity,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocalParticipantWidgetState
    extends _ParticipantWidgetState<LocalParticipantWidget> {
  @override
  LC.LocalTrackPublication<LC.LocalVideoTrack>? get videoPublication =>
      widget.participant.videoTracks
          .where((element) => element.sid == widget.videoTrack?.sid)
          .firstOrNull;

  @override
  LC.LocalTrackPublication<LC.LocalAudioTrack>? get firstAudioPublication =>
      widget.participant.audioTracks.firstOrNull;

  @override
  LC.VideoTrack? get activeVideoTrack => widget.videoTrack;
}

class _RemoteParticipantWidgetState
    extends _ParticipantWidgetState<RemoteParticipantWidget> {
  @override
  LC.RemoteTrackPublication<LC.RemoteVideoTrack>? get videoPublication =>
      widget.participant.videoTracks
          .where((element) => element.sid == widget.videoTrack?.sid)
          .firstOrNull;

  @override
  LC.RemoteTrackPublication<LC.RemoteAudioTrack>? get firstAudioPublication =>
      widget.participant.audioTracks.firstOrNull;

  @override
  LC.VideoTrack? get activeVideoTrack => widget.videoTrack;
}
