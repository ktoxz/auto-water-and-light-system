import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/control_screen.dart';
import 'screens/voice_screen.dart';
import 'screens/alerts_screen.dart';
import 'services/mqtt_service.dart';
import 'services/websocket_service.dart';
import 'services/stt_service.dart';

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatefulWidget {
  const SmartHomeApp({super.key});

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp> {
  late final MqttService mqttService;
  late final WebSocketService wsService;
  late final SttService sttService;

  @override
  void initState() {
    super.initState();
    mqttService = MqttService();
    wsService = WebSocketService();
    sttService = SttService(
      wsService: wsService,
      mqttService: mqttService,
    );
  }

  @override
  void dispose() {
    mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MqttService>.value(value: mqttService),
        Provider<WebSocketService>.value(value: wsService),
        Provider<SttService>.value(value: sttService),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Home IoT',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        ),
        home: AppBootstrap(
          mqttService: mqttService,
          sttService: sttService,
        ),
      ),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  final MqttService mqttService;
  final SttService sttService;

  const AppBootstrap({
    super.key,
    required this.mqttService,
    required this.sttService,
  });

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      widget.mqttService.connect(),
      widget.sttService.detectMode(),
    ]).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('Bootstrap: timeout — vào app luôn');
        return [];
      },
    );

    print('Bootstrap: done, MQTT=${widget.mqttService.isConnected}');

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang kết nối hệ thống...'),
                ],
              ),
            ),
          );
        }
        return const MainApp();
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ControlScreen(),
    VoiceScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Điều khiển'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Voice'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Cảnh báo'),
        ],
      ),
    );
  }
}
