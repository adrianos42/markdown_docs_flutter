import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:markdown_docs/markdown_docs.dart' as md;
import 'package:path/path.dart' as path;

import 'render.dart';

/// A widget for markdown content.
class Markdown extends StatefulWidget {
  /// Create a [Markdown] component.
  const Markdown({required this.text, super.key});

  /// The markdown text to be parsed.
  final String text;

  @override
  _MarkdownState createState() => _MarkdownState();
}

class _MarkdownState extends State<Markdown> {
  List<md.Node>? _nodes;
  final md.Document? _document = md.Document();

  void _parseText() {
    _nodes ??= _document!
        .parseLines(LineSplitter.split(widget.text).toList(growable: false));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(Markdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text) {
      _nodes = null;
      try {
        _parseText();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;

    try {
      _parseText();

      return FlutterRendererCode(colorScheme: colorScheme, textTheme: textTheme)
          .render(_nodes!);
    } catch (_) {}

    return const SizedBox();
  }
}

class _ResolveImageTypeHttp {
  const _ResolveImageTypeHttp(this.type, this.result);

  final String type;
  final Uint8List result;
}

class MarkdownImage extends StatefulWidget {
  const MarkdownImage(
    this.url, {
    this.imageDirectory,
    this.title,
    this.alternative,
  });

  final String url;

  final String? alternative;

  final String? title;

  ///
  final String? imageDirectory;

  @override
  _MarkdownImageState createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<MarkdownImage> {
  static String _resolveTypeFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/svg+xml':
        return 'svg';
      case 'image/webp':
      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
        return 'any';
      default:
        throw 'Invalid data type';
    }
  }

  static Future<_ResolveImageTypeHttp> _resolveNetworkImage(Uri uri) async {
    final HttpClient httpClient = HttpClient();
    final HttpClientRequest request = await httpClient.getUrl(uri);

    final HttpClientResponse response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Could not get network asset', uri: uri);
    }

    return _ResolveImageTypeHttp(
        _resolveTypeFromMimeType(response.headers.contentType!.mimeType),
        await consolidateHttpClientResponseBytes(response));
  }

  Widget _errorBuilder() {
    if (widget.title != null || widget.alternative != null) {
      return Text(widget.title ?? widget.alternative!);
    } else {
      return const Icon(Icons.image_not_supported);
    }
  }

  Widget _getNetworkImage(Uri uri) {
    if (path.extension(uri.path) == '.svg') {
      return _errorBuilder();
    } else {
      return Image.network(
        uri.toString(),
        errorBuilder: (context, _, __) => _errorBuilder(),
      ); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.parse(widget.url);

    if (uri.scheme == 'https') {
      return _getNetworkImage(uri);
    } else if (uri.scheme == 'data') {
      if (_resolveTypeFromMimeType(uri.data!.mimeType) == 'svg') {
        return _errorBuilder();
      } else {
        return Image.memory(
          uri.data!.contentAsBytes(),
          errorBuilder: (context, _, __) => _errorBuilder(),
        );
      }
    } else if (uri.scheme.isEmpty) {
      if (path.extension(uri.path) == '.svg') {
        return _errorBuilder();
      } else {
        return Image.asset(
          uri.path,
          errorBuilder: (context, _, __) => _errorBuilder(),
        );
      }
    } else {
      return const SizedBox();
    }
  }
}

/// The button used in text for links.
class LinkButton extends StatefulWidget {
  /// Creates a [LinkButton].
  const LinkButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.style,
  }) : super(key: key);

  /// Called when button is pressed.
  final VoidCallback onPressed;

  /// The button text.
  final TextSpan text;

  ///
  final TextStyle style;

  @override
  _LinkButtonState createState() => _LinkButtonState();
}

class _LinkButtonState extends State<LinkButton>
    with ComponentStateMixin, SingleTickerProviderStateMixin {
  void _handleHoverEntered() {
    if (!hovered && !_globalPointerDown) {
      hovered = true;
      _updateColor();
    }
  }

  void _handleHoverExited() {
    if (hovered) {
      hovered = false;
      _updateColor();
    }
  }

  void _handleHover() {
    if (!hovered && !pressed && !_globalPointerDown) {
      hovered = true;
      _updateColor();
    }
  }

  void _handleTapUp(TapUpDetails event) {
    if (pressed) {
      pressed = false;
      _updateColor();
    }
  }

  void _handleTapDown(TapDownDetails event) {
    if (!pressed) {
      pressed = true;
      _updateColor();
    }
  }

  void _handleTapCancel() {
    pressed = false;
    hovered = false;
    _updateColor();
  }

  bool _globalPointerDown = false;

  void _mouseRoute(PointerEvent event) {
    _globalPointerDown = event.down;
  }

  late AnimationController _controller;

  ColorTween? _color;

  void _handleTap() => widget.onPressed();

  void _updateColor() {
    if (mounted) {
      final TextTheme textTheme = Theme.of(context).textTheme;

      final Color foregroundColor;

      final Color pressedForeground = textTheme.textLow;

      final Color enabledForeground = textTheme.textPrimaryHigh;

      final Color hoveredForeground = textTheme.textHigh;

      foregroundColor = pressed
          ? pressedForeground
          : hovered
              ? hoveredForeground
              : enabledForeground;

      final bool wasPressed = pressed;
      final bool wasHovered = hovered;

      if (_controller.isAnimating) {
        return;
      }
      _color = ColorTween(
        begin: _color?.end ?? foregroundColor,
        end: foregroundColor,
      );

      _controller.forward(from: 0.0).then((_) {
        if (wasPressed != pressed || wasHovered != hovered) {
          _updateColor();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      value: 1.0,
    );

    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_mouseRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_mouseRoute);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final ButtonThemeData buttonThemeData = ButtonTheme.of(context);

    _controller.duration = buttonThemeData.animationDuration;

    if (_color == null) {
      _updateColor();
    }

    Widget result = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final Color? foreground =
            _color!.evaluate(AlwaysStoppedAnimation(_controller.value));

        final TextStyle textStyle = widget.style.copyWith(
          color: foreground,
        );

        return Text.rich(
          widget.text,
          style: textStyle,
        );
      },
    );

    result = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleHoverEntered(),
      onExit: (_) => _handleHoverExited(),
      onHover: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          _handleHover();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: result,
      ),
    );

    return result;
  }
}
