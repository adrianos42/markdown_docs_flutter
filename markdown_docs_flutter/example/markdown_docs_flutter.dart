import 'package:desktop/desktop.dart';

void main() {
  runApp(
    const DesktopApp(
      home: Home(),
      //home: DocApp(),
      showPerformanceOverlay: false,
      debugShowCheckedModeBanner: true,
    ),
  );
}

class Home extends StatefulWidget {
  const Home();

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text('uy');
  }
}
