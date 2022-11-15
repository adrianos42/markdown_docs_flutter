import 'dart:math' as math;

import 'package:desktop/desktop.dart';
import 'package:markdown_docs_flutter/markdown_docs_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

const int _kDefaultBorderColorIndex = 4;

void main() {
  runApp(
    const DesktopApp(
      home: Home(initialText: markdownText, title: 'doc'),
      //home: DocApp(),
      showPerformanceOverlay: false,
      debugShowCheckedModeBanner: false,
    ),
  );
}

const markdownText = '''
# doc
''';

class Home extends StatefulWidget {
  const Home({this.initialText = '', this.title = ''});

  final String initialText;

  final String title;

  @override
  _HomeState createState() => _HomeState();
}

enum Visibility {
  text,
  preview,
  split,
}

class _HomeState extends State<Home> {
  late TextEditingController controller;

  final textScrollController = ScrollController();
  final scrollController = ScrollController();
  Visibility visibility = Visibility.split;

  late TextEditingController titletextEditingController;

  void _openFile() async {
    const typeGroup =
        XTypeGroup(label: 'markdown text', extensions: ['md']);

    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    controller.text = await file!.readAsString();
  }

  void _saveFile() async {
    final fileName = '${titletextEditingController.text}.md';
    final savePath = await getSavePath(suggestedName: fileName);

    if (savePath != null) {
      final fileData = Uint8List.fromList(controller.text.codeUnits);
      final textFile = XFile.fromData(
        fileData,
        mimeType: 'text/plain',
        name: fileName,
      );

      await textFile.saveTo(savePath);
    }
  }

  Widget _createHeader() {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;

    return Container(
      height: 36.0,
      decoration: BoxDecoration(
          color: colorScheme.background[_kDefaultBorderColorIndex]),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          Button.icon(
            Icons.file_upload,
            onPressed: _openFile,
          ),
          Button.icon(
            Icons.save,
            onPressed: _saveFile,
          ),
          SizedBox(
            width: 200.0,
            child: TextField(
              controller: titletextEditingController,
              style: textTheme.caption,
              decoration: const BoxDecoration(),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Button(
                body: Transform.rotate(
                  angle: math.pi / 2.0,
                  child: const Icon(Icons.splitscreen),
                ),
                onPressed: () => setState(() => visibility = Visibility.split),
                active: visibility == Visibility.split,
              ),
              Button.icon(
                Icons.visibility,
                onPressed: () =>
                    setState(() => visibility = Visibility.preview),
                active: visibility == Visibility.preview,
              ),
              Button.icon(
                Icons.edit,
                onPressed: () => setState(() => visibility = Visibility.text),
                active: visibility == Visibility.text,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return ScrollConfiguration(
      behavior: const DesktopScrollBehavior(isAlwaysShown: true),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        controller: scrollController,
        child: Markdown(text: controller.text),
      ),
    );
  }

  Widget _buildEdit() {
    return TextField(
      controller: controller,
      scrollController: textScrollController,
      maxLines: null,
      expands: true,
      autofocus: true,
      scrollBehavior: const DesktopScrollBehavior(
        isAlwaysShown: true,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            width: 1.0,
            color: Theme.of(context)
                .colorScheme
                .background[_kDefaultBorderColorIndex],
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 4.0),
      cursorWidth: 2.0,
    );
  }

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.initialText);
    titletextEditingController = TextEditingController(text: widget.title);

    controller.addListener(() {
      setState(() {});
    });

    scrollController.addListener(() {
      if (textScrollController.hasClients) {
        final extent =
            scrollController.offset / scrollController.position.maxScrollExtent;
        final position = textScrollController.position;

        textScrollController.jumpTo(
          clampDouble(
            position.maxScrollExtent * extent,
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
    });

    textScrollController.addListener(() {
      if (scrollController.hasClients) {
        final extent = textScrollController.offset /
            textScrollController.position.maxScrollExtent;
        final position = scrollController.position;

        scrollController.jumpTo(
          clampDouble(
            position.maxScrollExtent * extent,
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget result;

    switch (visibility) {
      case Visibility.text:
        result = _buildEdit();
        break;
      case Visibility.preview:
        result = _buildPreview();
        break;
      case Visibility.split:
        result = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: _buildEdit(),
            ),
            Flexible(
              flex: 1,
              child: _buildPreview(),
            ),
          ],
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _createHeader(),
        Expanded(child: result),
      ],
    );
  }
}
