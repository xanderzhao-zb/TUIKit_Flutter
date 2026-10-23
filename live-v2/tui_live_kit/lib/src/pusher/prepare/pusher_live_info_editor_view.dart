import 'dart:convert';

import 'package:flutter/material.dart';

import '../../common/live_image_loader.dart';
import '../../common/live_kit_resources.dart';
import '../../common/theme/live_text_input_view.dart';

/// 主题输入的命令入口。
class PusherLiveInfoEditorController {
  final TextEditingController textController =
      TextEditingController(text: LiveKitResources.localizedString('tuilivekit.pusher.default_title'));
  final FocusNode focusNode = FocusNode();

  String get title => textController.text;

  /// 编辑中不覆盖用户输入。
  void bind({required String title}) {
    if (focusNode.hasFocus) {
      return;
    }
    // TextInputFormatter covers user edits; programmatic bindings need the
    // same UTF-8 budget as iOS LiveTextInputView.setContent.
    final accepted = StringBuffer();
    var remaining = 100;
    for (final character in title.characters) {
      final bytes = utf8.encode(character).length;
      if (bytes > remaining) break;
      accepted.write(character);
      remaining -= bytes;
    }
    final limited = accepted.toString();
    if (textController.text != limited) {
      textController.text = limited;
    }
  }

  void beginEditing() {
    focusNode.requestFocus();
  }

  void endEditing() {
    focusNode.unfocus();
  }

  void dispose() {
    textController.dispose();
    focusNode.dispose();
  }
}

class PusherLiveInfoEditorView extends StatelessWidget {
  const PusherLiveInfoEditorView({
    super.key,
    required this.controller,
    required this.coverURL,
    this.onChangeCover,
    this.onTitleChanged,
  });

  final PusherLiveInfoEditorController controller;

  /// 当前封面。
  final String coverURL;

  /// 封面缩略图与其下方文案共用的入口。
  final VoidCallback? onChangeCover;
  final ValueChanged<String>? onTitleChanged;

  /// UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1)
  static const Color _coverBackgroundColor = Color(0xFF21263B);

  /// UIColor.white.withAlphaComponent(0.16)
  static const Color _coverBorderColor = Color(0x29FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Column(
      // 修改主题入口改为 top = titleField.bottom、
      // bottom = superview.bottom - 10，整体高度由内容决定而非固定 153。
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 缩略图与其下方文案是同一个点击入口。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            controller.endEditing();
            onChangeCover?.call();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _coverBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _coverBorderColor, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _PusherCoverImage(coverURL: coverURL),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                  height: 14,
                  child: Text(
                    LiveKitResources.localizedString(
                      'tuilivekit.pusher.prepare.change_cover',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  )),
            ],
          ),
        ),
        // 封面区 58 + 6 + 14 = 78，标题输入框在 390pt 基准上仍位于 top 90。
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 45),
          child: LiveTextInputView(
            controller: controller.textController,
            focusNode: controller.focusNode,
            characterLimit: 100,
            lengthUnit: LiveTextLengthUnit.utf8Bytes,
            onChanged: onTitleChanged,
            maximumLines: 3,
            minimumHeight: 28,
            limitMessageKey: 'tuilivekit.pusher.prepare.topic_byte_limit',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.2, fontWeight: FontWeight.w600),
            textInputAction: TextInputAction.done,
            onSubmitted: controller.endEditing,
          ),
        ),
        SizedBox(
          height: 25,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.beginEditing,
              child: SizedBox(
                height: 25,
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    LiveKitResources.localizedString('tuilivekit.pusher.prepare.edit_topic'),
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _PusherCoverImage extends StatefulWidget {
  const _PusherCoverImage({required this.coverURL});
  final String coverURL;

  @override
  State<_PusherCoverImage> createState() => _PusherCoverImageState();
}

class _PusherCoverImageState extends State<_PusherCoverImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(_PusherCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coverURL != oldWidget.coverURL) _load();
  }

  void _load() {
    final provider = LiveImageLoader.provider(widget.coverURL);
    final stream = provider?.resolve(createLocalImageConfiguration(context));
    if (stream?.key == _stream?.key) return;
    _removeListener();
    final request = ++_request;
    if (stream == null) return;
    _stream = stream;
    _listener = ImageStreamListener((image, synchronousCall) {
      if (!mounted || request != _request) {
        image.dispose();
        return;
      }
      final previous = _image;
      setState(() => _image = image);
      // The previous RawImage can still belong to the current render frame.
      // Retire its image handle after the replacement has been painted.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    }, onError: (Object error, StackTrace? stackTrace) {
      // Keep the last successful cover during replacement and failed loads.
    });
    stream.addListener(_listener!);
  }

  void _removeListener() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _request++;
    _removeListener();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawImage(
        image: _image?.image,
        scale: _image?.scale ?? 1,
        fit: BoxFit.cover,
      );
}
