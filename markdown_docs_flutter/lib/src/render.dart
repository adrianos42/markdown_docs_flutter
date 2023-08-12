import 'dart:math' as math;

import 'package:desktop/desktop.dart';
import 'package:markdown_docs/markdown_docs.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'code_languages/dart_code.dart';
import 'markdown.dart';

const _kFontFamily = 'IBM Plex Sans';
const _kFontPackage = 'desktop';
const _kDefaultItemPadding = 16.0;
const _kDefaultBlockBackgroundIndex = 4;

final List<md.InlineSyntax> _markdownSyntaxes = [
  md.StrikethroughSyntax(),
  md.AutolinkExtensionSyntax(),
];

final List<md.BlockSyntax> _markdownBlockSyntaxes = [
  const md.FencedCodeBlockSyntax(),
  const md.UnorderedListWithCheckboxSyntax(),
  const md.OrderedListWithCheckboxSyntax(),
  const md.HeaderSyntax(),
  const md.SetextHeaderSyntax(),
  const md.TableSyntax(),
];

/// Renders [nodes] to Flutter.
// String renderToFlutterCode(List<md.Node> nodes) =>
//     FlutterRendererCode().render(nodes);

/// Translates a parsed AST to Flutter.
class FlutterRendererCode implements md.NodeVisitor {
  /// Creates a [FlutterRendererCode] element.
  FlutterRendererCode({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  final List<List<Widget>> _children = [];
  final List<TextStyle> _lastTextStyle = [];

  final List<List<InlineSpan>> _spans = [];

  md.HeaderLevel? _previousHeader;
  bool _isFirstHeader = false;

  final List<bool> _hasOpenSpan = [false];

  /// Renders the parsed AST.
  Widget render(List<md.Node> nodes) {
    _lastTextStyle.add(textTheme.body1);

    _children.add([]);

    for (final node in nodes) {
      node.accept(this);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _children.first,
    );
  }

  @override
  void visitText(md.Text text) {
    final textContent = text.textContent.replaceAll('\n', ' ');

    if (_hasOpenSpan.last) {
      _spans.last.add(TextSpan(text: textContent));
    } else {
      _children.last.add(Text(textContent));
    }
  }

  @override
  void visitParagraph(md.Paragraph paragraph) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `Paragraph`';
    }

    _spans.add([]);
    _hasOpenSpan.add(true);

    paragraph.visitChildren();

    _children.last.add(
      Padding(
        padding: const EdgeInsets.only(bottom: _kDefaultItemPadding),
        child: Text.rich(
          TextSpan(children: _spans.last),
        ),
      ),
    );

    _spans.removeLast();
    _hasOpenSpan.removeLast();
    _previousHeader = null;
  }

  @override
  void visitListParagraph(md.ListParagraph paragraph) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `ListParagraph`';
    }

    _spans.add([]);
    _hasOpenSpan.add(true);

    paragraph.visitChildren();

    _children.last.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text.rich(
          TextSpan(
            children: _spans.last,
          ),
        ),
      ),
    );

    _spans.removeLast();
    _hasOpenSpan.removeLast();
  }

  @override
  void visitCode(md.Code code) {
    final spanText = DartCodeSpan(code.textContent).buildTextSpan(
      colorScheme: colorScheme,
      textTheme: textTheme,
    );

    if (_hasOpenSpan.last) {
      _spans.last.add(spanText);
    } else {
      _children.last.add(RichText(
        text: spanText,
      ));
    }
  }

  @override
  void visitCodeBlock(md.CodeBlock code) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `CodeBlock`';
    }

    _children.last.add(
      Padding(
        padding: const EdgeInsets.only(bottom: _kDefaultItemPadding),
        child: ColoredBox(
          color: colorScheme.background[_kDefaultBlockBackgroundIndex],
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SelectableText(code.textContent),
          ),
        ),
      ),
    );

    _previousHeader = null;
  }

  @override
  void visitFencedCodeBlock(md.FencedCodeBlock code) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `FencedCodeBlock`';
    }

    final language = code.language;

    final TextSpan spanText;

    switch (language) {
      case 'dart':
        spanText = DartCodeSpan(code.textContent).buildTextSpan(
          colorScheme: colorScheme,
          textTheme: textTheme,
        );
        break;
      default:
        // TODO(as): See generic code generator.
        spanText = DartCodeSpan(code.textContent).buildTextSpan(
          colorScheme: colorScheme,
          textTheme: textTheme,
        );
    }

    _children.last.add(
      Padding(
        padding: const EdgeInsets.only(bottom: _kDefaultItemPadding),
        child: DecoratedBox(
          decoration: BoxDecoration(
              border:
                  Border.all(width: 1.0, color: colorScheme.background[12])),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SelectableText.rich(spanText),
          ),
        ),
      ),
    );

    _previousHeader = null;
  }

  final List<bool> _hadBlockQuoteHeader = [];
  int _blockQuoteDepth = 0;

  @override
  void visitBlockQuote(md.BlockQuote blockQuote) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `BlockQuote`';
    }

    _blockQuoteDepth += 1;
    _hadBlockQuoteHeader.add(false);

    _children.add([]);

    blockQuote.visitChildren();

    final children = _children.last;
    _children.removeLast();

    _children.last.add(
      Padding(
        padding: const EdgeInsets.only(bottom: _kDefaultItemPadding),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 4.0,
                color: colorScheme.background[16],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );

    _blockQuoteDepth -= 1;
    _hadBlockQuoteHeader.removeLast();
    _previousHeader = null;
  }

  bool _isNextHeaderLevel(md.HeaderLevel previousLevel, md.HeaderLevel level) {
    switch (level) {
      case md.HeaderLevel.header1:
        return false;
      case md.HeaderLevel.header2:
        return previousLevel == md.HeaderLevel.header1;
      case md.HeaderLevel.header3:
        return previousLevel == md.HeaderLevel.header2 ||
            _isNextHeaderLevel(previousLevel, md.HeaderLevel.header2);
      case md.HeaderLevel.header4:
        return previousLevel == md.HeaderLevel.header3 ||
            _isNextHeaderLevel(previousLevel, md.HeaderLevel.header3);
      case md.HeaderLevel.header5:
        return previousLevel == md.HeaderLevel.header4 ||
            _isNextHeaderLevel(previousLevel, md.HeaderLevel.header4);
      case md.HeaderLevel.header6:
        return previousLevel == md.HeaderLevel.header5 ||
            _isNextHeaderLevel(previousLevel, md.HeaderLevel.header5);
    }
  }

  md.HeaderLevel? _openHeaderLevel;

  @override
  void visitHeader(md.Header header) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `Header`';
    }

    final TextStyle textStyle;
    double? topPadding;
    final double bottomPadding;

    _openHeaderLevel = header.level;

    switch (header.level) {
      case md.HeaderLevel.header1:
        textStyle = textTheme.header;
        topPadding = 24.0;
        bottomPadding = 16.0;
        break;
      case md.HeaderLevel.header2:
        textStyle = textTheme.subheader;
        bottomPadding = 16.0;

        if (_previousHeader == null ||
            !_isNextHeaderLevel(_previousHeader!, header.level)) {
          topPadding = 16.0;
        }
        break;
      case md.HeaderLevel.header3:
        textStyle = textTheme.title;
        bottomPadding = 16.0;

        if (_previousHeader == null ||
            !_isNextHeaderLevel(_previousHeader!, header.level)) {
          topPadding = 8.0;
        }
        break;
      case md.HeaderLevel.header4:
        textStyle = textTheme.subtitle;
        bottomPadding = 16.0;

        if (_previousHeader == null ||
            !_isNextHeaderLevel(_previousHeader!, header.level)) {
          topPadding = 8.0;
        }
        break;
      case md.HeaderLevel.header5:
        textStyle = const TextStyle(
          fontFamily: _kFontFamily,
          package: _kFontPackage,
          fontWeight: FontWeight.w500,
          fontSize: 18.0,
        );

        bottomPadding = 16.0;

        if (_previousHeader == null ||
            !_isNextHeaderLevel(_previousHeader!, header.level)) {
          topPadding = 8.0;
        }
        break;
      case md.HeaderLevel.header6:
        textStyle = const TextStyle(
          fontFamily: _kFontFamily,
          package: _kFontPackage,
          fontWeight: FontWeight.w500,
          fontSize: 16.0,
        );

        bottomPadding = 16.0;

        if (_previousHeader == null ||
            !_isNextHeaderLevel(_previousHeader!, header.level)) {
          topPadding = 8.0;
        }
        break;
    }

    if (_blockQuoteDepth > 0 && !_hadBlockQuoteHeader.last) {
      topPadding = 0.0;
      _hadBlockQuoteHeader.last = true;
    }

    _isFirstHeader = _children.first.isEmpty;

    _spans.add([]);
    _hasOpenSpan.add(true);
    _lastTextStyle.add(textStyle);

    header.visitChildren();

    _children.last.add(
      Padding(
        padding: EdgeInsets.only(
          bottom: bottomPadding,
          top: topPadding ?? 0.0,
        ),
        child: Text.rich(
          TextSpan(
            style: textStyle,
            children: _spans.last,
          ),
        ),
      ),
    );

    _spans.removeLast();

    _previousHeader = header.level;
    _lastTextStyle.removeLast();
    _hasOpenSpan.removeLast();
    _openHeaderLevel = null;
  }

  bool _linkHasTooltip = false;

  @override
  void visitLink(md.Link link) {
    final Uri uri = Uri.parse(link.url);

    _spans.add([]);
    _hasOpenSpan.add(true);

    link.visitChildren();

    Widget button = LinkButton(
      text: TextSpan(
        children: _spans.last,
      ),
      onPressed: () async {
        await launchUrl(
          Uri.parse(link.url),
        );
      },
      style: _lastTextStyle.last,
    );

    _spans.removeLast();
    _hasOpenSpan.removeLast();

    _linkHasTooltip = uri.scheme == 'https';

    if (_linkHasTooltip) {
      button = Tooltip(
        message: link.url,
        child: button,
      );
    }

    if (_hasOpenSpan.last) {
      _spans.last.add(WidgetSpan(child: button));
    } else {
      _children.last.add(button);
    }
  }

  @override
  void visitBold(md.Bold bold) {
    final style = _lastTextStyle.last.copyWith(
      fontWeight: _openHeaderLevel == md.HeaderLevel.header1 ||
              _openHeaderLevel == md.HeaderLevel.header2
          ? FontWeight.w500
          : FontWeight.w700,
    );

    _lastTextStyle.add(style);

    _spans.add([]);
    _hasOpenSpan.add(true);

    bold.visitChildren();

    final children = _spans.last;

    _spans.removeLast();
    _hasOpenSpan.removeLast();

    if (_hasOpenSpan.last) {
      _spans.last.add(
        TextSpan(
          style: style,
          children: children,
        ),
      );
    } else {
      _children.last.add(
        Text.rich(
          TextSpan(
            style: style,
            children: children,
          ),
        ),
      );
    }

    _lastTextStyle.removeLast();
  }

  @override
  void visitItalic(md.Italic italic) {
    final style = _lastTextStyle.last.copyWith(fontStyle: FontStyle.italic);

    _lastTextStyle.add(style);

    _spans.add([]);
    _hasOpenSpan.add(true);

    italic.visitChildren();

    final children = _spans.last;
    _spans.removeLast();
    _hasOpenSpan.removeLast();

    if (_hasOpenSpan.last) {
      _spans.last.add(TextSpan(style: style, children: children));
    } else {
      _children.last.add(
        Text.rich(
          TextSpan(style: style, children: children),
        ),
      );
    }

    _lastTextStyle.removeLast();
  }

  @override
  void visitStrikethrough(md.Strikethrough strikethrough) {
    final style =
        _lastTextStyle.last.copyWith(decoration: TextDecoration.lineThrough);

    _lastTextStyle.add(style);

    _spans.add([]);
    _hasOpenSpan.add(true);

    strikethrough.visitChildren();

    final children = _spans.last;

    _hasOpenSpan.removeLast();
    _spans.removeLast();

    if (_hasOpenSpan.last) {
      _spans.last.add(
        TextSpan(
          style: style,
          children: children,
        ),
      );
    } else {
      _children.last.add(Text.rich(
        TextSpan(
          style: style,
          children: children,
        ),
      ));
    }

    _lastTextStyle.removeLast();
  }

  @override
  void visitHorizontalRule(md.HorizontalRule horizontalRule) {
    final Widget widget = Container(
      margin: const EdgeInsets.only(top: 4.0, bottom: 11.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.background[12],
            width: 1.0,
          ),
        ),
      ),
    );

    if (_hasOpenSpan.last) {
      _spans.last.add(
        WidgetSpan(child: widget, alignment: PlaceholderAlignment.middle),
      );
    } else {
      _children.last.add(widget);
    }

    _previousHeader = null;
  }

  int _orderedListDepth = 0;
  final List<int> _orderedListStartNumber = [];

  @override
  void visitOrderedList(md.OrderedList orderedList) {
    _hasOpenSpan.add(false);

    _orderedListStartNumber.add(orderedList.startNumber ?? 1);

    _orderedListDepth += 1;

    _children.add([]);

    orderedList.visitChildren();

    _hasOpenSpan.removeLast();

    final children = _children.last;
    _children.removeLast();

    final Widget widget = Padding(
      padding: EdgeInsets.only(
        bottom: _orderedListDepth == 0 ? _kDefaultItemPadding : 0.0,
        left: _orderedListDepth == 0 ? 16.0 : 0.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (_hasOpenSpan.last) {
      _spans.last.add(WidgetSpan(child: widget));
    } else {
      _children.last.add(widget);
    }

    _orderedListStartNumber.removeLast();
    _orderedListDepth -= 1;
    _previousHeader = null;
  }

  @override
  void visitOrderedListItem(md.OrderedListItem listElement) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `OrderedListItem`';
    }

    _children.add([]);

    listElement.visitChildren();

    final children = _children.last;
    _children.removeLast();

    _children.last.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: '${_orderedListStartNumber.last}. ',
              style: textTheme.body1.copyWith(
                fontWeight: FontWeight.bold,
                color: textTheme.textLow,
              ),
              children: [
                if (listElement.checkbox != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _getCheckboxWidget(listElement.checkbox!),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );

    _orderedListStartNumber.last += 1;
  }

  int _unorderedListDepth = 0;

  Widget _getCheckboxWidget(md.Checkbox checkbox) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Checkbox(
        value: checkbox.checked,
        theme: const CheckboxThemeData(
          containerSize: 16.0,
        ),
      ),
    );
  }

  @override
  void visitUnorderedList(md.UnorderedList unorderedList) {
    _hasOpenSpan.add(false);

    _unorderedListDepth += 1;

    _children.add([]);

    unorderedList.visitChildren();

    _hasOpenSpan.removeLast();
    final children = _children.last;
    _children.removeLast();

    final widget = Padding(
      padding: EdgeInsets.only(
        bottom: _unorderedListDepth == 0 ? _kDefaultItemPadding : 0.0,
        left: _unorderedListDepth == 0 ? 16.0 : 0.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (_hasOpenSpan.last) {
      _spans.last.add(WidgetSpan(child: widget));
    } else {
      _children.last.add(widget);
    }

    _unorderedListDepth -= 1;
    _previousHeader = null;
  }

  @override
  void visitUnorderedListItem(md.UnorderedListItem listElement) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `UnorderedListItem`';
    }

    final Widget icon = _unorderedListDepth.isOdd
        ? Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.circle,
              color: textTheme.textLow,
              size: 8.0,
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.radioButtonUnchecked,
              color: textTheme.textLow,
              size: 8.0,
            ),
          );

    _children.add([]);
    listElement.visitChildren();

    final children = _children.last;
    _children.removeLast();

    _children.last.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  if (listElement.checkbox != null)
                    _getCheckboxWidget(listElement.checkbox!)
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void visitImage(md.Image image) {
    final widget = MarkdownImage(
      image.destination,
      alternative: image.alternative,
      title: image.title,
    );

    if (_hasOpenSpan.last) {
      _spans.last.add(
        WidgetSpan(child: widget),
      );
    } else {
      _children.last.add(widget);
    }
  }

  List<int> _tableCellSizes = [];
  ListTableHeader? _listTableHeader;
  late List<ListTableRow> _listTableRows;

  @override
  void visitTable(md.Table table) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `Table`';
    }

    _listTableHeader = null;

    _tableCellSizes = List.filled(table.columnCount, 0);
    _listTableRows = [];

    table.visitChildren();

    final tableCellTotal = _tableCellSizes.fold(0, (p, e) => p + e);

    final Map<int, double> colFraction = {};

    for (int i = 0; i < table.columnCount; i += 1) {
      colFraction[i] = _tableCellSizes[i] / tableCellTotal;
    }

    final widget = Padding(
      padding: const EdgeInsets.only(bottom: _kDefaultItemPadding),
      child: ListTable(
        allowColumnDragging: true,
        tableBorder: TableBorder.all(color: colorScheme.shade[30], width: 1.0),
        colCount: table.columnCount,
        colFraction: colFraction,
        header: _listTableHeader!,
        rows: _listTableRows,
      ),
    );

    _children.last.add(widget);

    _previousHeader = null;
    _listTableRows = [];
  }

  @override
  void visitTableHeader(md.TableHeader tableHeader) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `TableHeader`';
    }

    _children.add([]);

    tableHeader.visitChildren();

    final children = _children.last;
    _children.removeLast();

    assert(children.length == _tableCellSizes.length,
        'Can only add rows with the same amount of columns');

    _listTableHeader = ListTableHeader(
      itemExtent: null,
      children: children,
    );
  }

  @override
  void visitTableRow(md.TableRow tableRow) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `TableRow`';
    }

    if (_hasOpenSpan.last) {
      throw 'Invalid state: `TableRow`';
    }

    _children.add([]);

    tableRow.visitChildren();

    final children = _children.last;
    _children.removeLast();

    assert(children.length == _tableCellSizes.length,
        'Can only add rows with the same amount of columns');

    _listTableRows.add(
      ListTableRow(
        itemExtent: null,
        children: children,
      ),
    );
  }

  @override
  void visitTableCell(md.TableCell tableCell) {
    if (_hasOpenSpan.last) {
      throw 'Invalid state: `TableCell`';
    }

    final WrapAlignment alignment;

    switch (tableCell.alignment) {
      case md.TableCellAlignment.right:
        alignment = WrapAlignment.end;
        break;
      case md.TableCellAlignment.center:
        alignment = WrapAlignment.center;
        break;
      case md.TableCellAlignment.left:
      default:
        alignment = WrapAlignment.start;
        break;
    }

    _children.add([]);

    tableCell.visitChildren();

    final children = _children.last;
    _children.removeLast();

    _children.last.add(
      Padding(
        padding: const EdgeInsets.all(_kDefaultItemPadding),
        child: Wrap(
          alignment: alignment,
          children: children,
        ),
      ),
    );

    _tableCellSizes[tableCell.columnIndex] = math.max(
      _tableCellSizes[tableCell.columnIndex],
      tableCell.textContent.length,
    );
  }
}