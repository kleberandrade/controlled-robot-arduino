enum Movement {
  stop('S'),
  forward('F'),
  backward('B'),
  left('L'),
  right('R');

  const Movement(this.code);
  final String code;
  String get frame => '$code\n';
}

/// Bounded ASCII decoder; damaged lines are discarded until LF.
class ReplyParser {
  String _line = '';
  bool _discard = false;
  List<String> add(List<int> bytes) {
    final lines = <String>[];
    for (final byte in bytes) {
      if (byte == 10) {
        if (!_discard && _line.isNotEmpty) lines.add(_line);
        _line = '';
        _discard = false;
      } else if (byte != 13 && !_discard) {
        if (byte < 32 || byte > 126 || _line.length >= 32) {
          _line = '';
          _discard = true;
        } else {
          _line += String.fromCharCode(byte);
        }
      }
    }
    return lines;
  }
}
