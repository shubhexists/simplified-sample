import 'package:flutter/material.dart';
import 'package:livekit_example/provider.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'pages/connect.dart';

void main() async {
  final format = DateFormat('HH:mm:ss');
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${format.format(record.time)}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(
      create: (context) => BoxColorProvider(),
      child: const LiveKitExampleApp()));
}

class LiveKitExampleApp extends StatefulWidget {
  const LiveKitExampleApp({
    Key? key,
  }) : super(key: key);

  @override
  State<LiveKitExampleApp> createState() => _LiveKitExampleAppState();
}

class _LiveKitExampleAppState extends State<LiveKitExampleApp> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Zoomtod',
        home: ConnectPage(),
      );
}
