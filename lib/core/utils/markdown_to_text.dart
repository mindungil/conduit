/// Converts markdown text to plain text suitable for text-to-speech.
///
/// Strips formatting while preserving the semantic meaning and readability
/// of the content for audio consumption.
class MarkdownToText {
  const MarkdownToText._();

  static final _thinkingBlockRegex = RegExp(
    r'<details\s+type="reasoning"[^>]*>.*?</details>',
    multiLine: true,
    dotAll: true,
  );
  static final _thinkTagRegex = RegExp(
    r'<think>.*?</think>',
    multiLine: true,
    dotAll: true,
  );
  static final _reasoningTagRegex = RegExp(
    r'<reasoning>.*?</reasoning>',
    multiLine: true,
    dotAll: true,
  );
  static final _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|[\u{FE00}-\u{FE0F}]|[\u{1F018}-\u{1F270}]|[\u{238C}-\u{2454}]|[\u{20D0}-\u{20FF}]',
    unicode: true,
  );
  static final _codeBlockRegex = RegExp(
    r'```[^\n]*\n(.*?)```',
    multiLine: true,
    dotAll: true,
  );
  static final _inlineCodeRegex = RegExp(r'`([^`]+)`');
  static final _boldItalicRegex = RegExp(r'\*\*\*([^*]+)\*\*\*');
  static final _boldRegex = RegExp(r'\*\*([^*]+)\*\*');
  static final _italicRegex = RegExp(r'\*([^*]+)\*|_([^_]+)_');
  static final _strikethroughRegex = RegExp(r'~~([^~]+)~~');
  static final _linkRegex = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  static final _imageRegex = RegExp(r'!\[([^\]]*)\]\([^)]+\)');
  static final _headingRegex = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true);
  static final _listItemRegex = RegExp(r'^[\s]*[-*+]\s+(.+)$', multiLine: true);
  static final _orderedListRegex = RegExp(
    r'^[\s]*\d+\.\s+(.+)$',
    multiLine: true,
  );
  static final _blockquoteRegex = RegExp(r'^>\s*(.+)$', multiLine: true);
  static final _horizontalRuleRegex = RegExp(
    r'^[\s]*[-*_]{3,}[\s]*$',
    multiLine: true,
  );
  static final _htmlTagRegex = RegExp(r'<[^>]+>');
  static final _htmlEntityRegex = RegExp(r'&[a-z]+;|&#\d+;|&#x[0-9a-f]+;');
  static final _multipleNewlinesRegex = RegExp(r'\n{3,}');
  static final _multipleSpacesRegex = RegExp(r' {2,}');

  /// Converts markdown text to plain text suitable for TTS.
  ///
  /// - Removes thinking/reasoning blocks
  /// - Removes emojis
  /// - Removes code blocks (replaces with descriptive text)
  /// - Strips all formatting (bold, italic, strikethrough)
  /// - Converts links to just their text
  /// - Removes images (or converts to alt text)
  /// - Simplifies headings
  /// - Preserves list structure with natural pauses
  /// - Removes HTML tags and entities
  /// - Normalizes whitespace
  static String convert(String markdown) {
    if (markdown.trim().isEmpty) {
      return '';
    }

    var text = markdown;

    // Remove thinking/reasoning blocks (must be done before general HTML tag removal)
    text = text.replaceAll(_thinkingBlockRegex, '');
    text = text.replaceAll(_thinkTagRegex, '');
    text = text.replaceAll(_reasoningTagRegex, '');

    // Remove emojis
    text = text.replaceAll(_emojiRegex, '');

    // Remove or replace code blocks with descriptive text
    text = text.replaceAllMapped(_codeBlockRegex, (match) {
      final code = match[1]?.trim() ?? '';
      if (code.isEmpty) {
        return '';
      }
      return ' (code block) ';
    });

    // Remove inline code backticks but keep the content
    text = text.replaceAllMapped(_inlineCodeRegex, (match) => match[1] ?? '');

    // Strip bold/italic/strikethrough formatting
    text = text.replaceAllMapped(_boldItalicRegex, (match) => match[1] ?? '');
    text = text.replaceAllMapped(_boldRegex, (match) => match[1] ?? '');
    text = text.replaceAllMapped(
      _italicRegex,
      (match) => match[1] ?? match[2] ?? '',
    );
    text = text.replaceAllMapped(
      _strikethroughRegex,
      (match) => match[1] ?? '',
    );

    // Convert links to just their text
    text = text.replaceAllMapped(_linkRegex, (match) => match[1] ?? '');

    // Remove images (or use alt text if available)
    text = text.replaceAllMapped(_imageRegex, (match) {
      final alt = match[1]?.trim() ?? '';
      return alt.isNotEmpty ? ' ($alt image) ' : '';
    });

    // Simplify headings (remove # symbols)
    text = text.replaceAllMapped(_headingRegex, (match) {
      final heading = match[1] ?? '';
      return '$heading.\n';
    });

    // Preserve list items with natural pauses
    text = text.replaceAllMapped(_listItemRegex, (match) => '${match[1]}. ');
    text = text.replaceAllMapped(_orderedListRegex, (match) => '${match[1]}. ');

    // Remove blockquote markers
    text = text.replaceAllMapped(_blockquoteRegex, (match) => match[1] ?? '');

    // Remove horizontal rules
    text = text.replaceAll(_horizontalRuleRegex, '');

    // Remove HTML tags
    text = text.replaceAll(_htmlTagRegex, '');

    // Decode HTML entities
    text = text.replaceAllMapped(_htmlEntityRegex, (match) {
      final entity = match[0] ?? '';
      return switch (entity) {
        '&nbsp;' => ' ',
        '&amp;' => '&',
        '&lt;' => '<',
        '&gt;' => '>',
        '&quot;' => '"',
        '&apos;' => "'",
        _ => entity,
      };
    });

    // Normalize whitespace
    text = text.replaceAll(_multipleNewlinesRegex, '\n\n');
    text = text.replaceAll(_multipleSpacesRegex, ' ');

    // Convert newlines to spaces for natural speech flow
    text = text.replaceAll('\n', ' ');

    // Final cleanup
    text = text.trim();

    return text;
  }
}
