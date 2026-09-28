import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'base_field.dart';
import 'field_helpers.dart';

/// Widget for Text, Long Text, and Small Text field types
class TextFieldWidget extends BaseField {
  const TextFieldWidget({
    super.key,
    required super.field,
    super.value,
    super.onChanged,
    super.enabled,
    super.style,
  });

  @override
  Widget buildField(BuildContext context) {
    final isLongText =
        field.fieldtype == 'Long Text' || field.fieldtype == 'Text';
    final maxLines = isLongText ? 5 : 3;
    final editable = enabled && !field.readOnly;

    Widget buildInput(ScrollController? scrollController) =>
        FormBuilderTextField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: ValueKey('text_${field.fieldname}'),
          name: field.fieldname ?? '',
          initialValue: value?.toString() ?? field.defaultValue ?? '',
          enabled: editable,
          inputFormatters: style?.inputFormatters,
          decoration: baseFieldDecoration(field, style: style),
          maxLines: maxLines,
          scrollController: scrollController,
          maxLength: (field.length != null && field.length! > 0)
              ? field.length
              : null,
          validator: field.reqd
              ? (value) => requiredValidator(value, field.displayLabel)
              : null,
          onChanged: (val) => onChanged?.call(val),
        );

    if (editable) return buildInput(null);
    return _DisabledTextScroll(builder: buildInput);
  }
}

/// Makes a disabled multi-line text box scrollable inside its fixed height.
///
/// Flutter wraps a disabled `TextField` in an `IgnorePointer`, so text past
/// `maxLines` is clipped with no way to reach it. This drives the field's own
/// scroll controller from a drag detector placed OUTSIDE that IgnorePointer.
/// The detector is attached only while the text actually overflows, so a
/// short disabled field still lets the page scroll exactly as before.
class _DisabledTextScroll extends StatefulWidget {
  const _DisabledTextScroll({required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<_DisabledTextScroll> createState() => _DisabledTextScrollState();
}

class _DisabledTextScrollState extends State<_DisabledTextScroll> {
  final ScrollController _controller = ScrollController();
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!mounted || !_controller.hasClients) return;
    final overflows = _controller.position.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
  }

  void _onDrag(DragUpdateDetails details) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (position.pixels - details.delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    // The tree shape stays fixed (only the callback toggles) so the form
    // field's state is never torn down when overflow changes. A null
    // callback registers no drag recognizer at all.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _overflows ? _onDrag : null,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
          return false;
        },
        child: widget.builder(_controller),
      ),
    );
  }
}
