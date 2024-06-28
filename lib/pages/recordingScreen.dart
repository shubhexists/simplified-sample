// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:livekit_example/controllers/playcontroller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FileListWidget extends StatefulWidget {
  const FileListWidget({Key? key}) : super(key: key);

  @override
  _FileListWidgetState createState() => _FileListWidgetState();
}

class _FileListWidgetState extends State<FileListWidget> {
  List<File> m4aFiles = [];
  late Player player;
  Set<int> playingIndexes = {};
  bool isPlaybackComplete = false;
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    getM4AFilesFromDirectory().then((files) {
      setState(() {
        m4aFiles = files.reversed.toList();
      });
    });
  }

  Future<List<File>> getM4AFilesFromDirectory() async {
    Directory? appDocDirectory = await getExternalStorageDirectory();
    String dir = appDocDirectory!.path + '/Recordings';
    Directory directory = Directory(dir);
    List<FileSystemEntity> fileList = directory.listSync();
    List<File> m4aFiles = fileList
        .where(
            (file) => file is File && file.path.toLowerCase().endsWith('.m4a'))
        .cast<File>()
        .toList();
    return m4aFiles;
  }

  void onPlaybackComplete() {
    setState(() {
      isPlaybackComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 34, 162, 29),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('Recordings',
                style: TextStyle(color: Colors.black, fontSize: 20)),
            TextButton(
                onPressed: () async {
                  player.stopMusic();
                  for (var i = 0; i < m4aFiles.length; i++) {
                    await m4aFiles[i].delete();
                  }
                  setState(() {
                    m4aFiles.clear();
                    playingIndexes.clear();
                  });
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.black),
                ))
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: m4aFiles.length,
        itemBuilder: (context, index) {
          File file = m4aFiles[index];
          bool isPlaying = playingIndexes.contains(index);
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: const BorderSide(width: 2),
            ),
            leading: IconButton(
                onPressed: () async {
                  if (isPlaying) {
                    player.stopMusic();
                    setState(() {
                      playingIndexes.remove(index);
                    });
                  } else {
                    player = Player(file.path)
                      ..onCompletion = onPlaybackComplete;
                    await player.setSource(file.path);
                    await player.player.setVolume(1);
                    player.playMusic();
                    setState(() {
                      playingIndexes.add(index);
                    });
                  }
                },
                icon: Icon(
                    isPlaybackComplete
                        ? Icons.play_circle_fill_outlined
                        : isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle_fill_outlined,
                    color: Colors.black,
                    size: 40)),
            title: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(file.path.split('/').last,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () async {
                      await file.delete();
                      setState(() {
                        m4aFiles.removeAt(index);
                        if (playingIndexes.contains(index)) {
                          playingIndexes.remove(index);
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                  )
                ],
              ),
            ),
            subtitle: Text(
              '${(file.lengthSync() / 1024).toStringAsFixed(2)} KB',
              style: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
