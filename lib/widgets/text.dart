import 'package:emoji_regex/emoji_regex.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gektusclashx/enum/enum.dart';

import '../state.dart';

/// The shared heading style for subscription and news cards on the dashboard.
TextStyle? dashboardCardTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface);

class TooltipText extends StatelessWidget {
  const TooltipText({
    super.key,
    required this.text,
  });
  final Text text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, container) {
          final maxWidth = container.maxWidth;
          final size = globalState.measure.computeTextSize(
            text,
          );
          if (maxWidth < size.width) {
            return Tooltip(
              preferBelow: false,
              message: text.data,
              child: text,
            );
          }
          return text;
        },
      );
}

class EmojiText extends StatelessWidget {
  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => RichText(
        textScaler: MediaQuery.of(context).textScaler,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        text: TextSpan(
          children: emojiTextSpans(text, style: style),
        ),
      );
}

/// Apply the bundled font to complete emoji sequences, including the optional
/// emoji presentation selector. Keep link gestures on each resulting span.
List<TextSpan> emojiTextSpans(String text,
    {TextStyle? style, GestureRecognizer? recognizer}) {
  final spans = <TextSpan>[];
  var lastEnd = 0;
  for (final match in emojiRegex().allMatches(text)) {
    if (match.start < lastEnd) {
      continue;
    }
    if (match.start > lastEnd) {
      spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
          recognizer: recognizer));
    }
    var end = match.end;
    if (end < text.length && text.codeUnitAt(end) == 0xfe0f) {
      end++;
    }
    spans.add(TextSpan(
        text: text.substring(match.start, end),
        recognizer: recognizer,
        style: (style ?? const TextStyle())
            .copyWith(fontFamily: FontFamily.twEmoji.value)));
    lastEnd = end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(
        text: text.substring(lastEnd), style: style, recognizer: recognizer));
  }
  return spans;
}
