/**********************************************************\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: http://www.hprose.com/                 |
|                   http://www.hprose.org/                 |
|                                                          |
\**********************************************************/
/**********************************************************\
 *                                                        *
 * bytes_io.dart                                          *
 *                                                        *
 * hprose bytes io for Dart.                              *
 *                                                        *
 * LastModified: Mar 4, 2015                              *
 * Author: Ma Bingyao <andot@hprose.com>                  *
 *                                                        *
\**********************************************************/
part of hprose.io;

class BytesIO {
  static const int _INIT_SIZE = 1024;
  static Uint8List _EMPTY_BYTES = new Uint8List(0);
  Uint8List _bytes = null;
  int _length = 0; // for write
  int _wmark = 0; // for write
  int _off = 0; // for read
  int _rmark = 0; // for read

  int _pow2roundup(int x) {
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x + 1;
  }

  void _grow(int n) {
    int required = _length + n;
    int size = _pow2roundup(required);
    if (_bytes != null) {
      size *= 2;
      if (size > _bytes.length) {
        var buf = new Uint8List(size);
        buf.setAll(0, _bytes);
        _bytes = buf;
      }
    } else {
      size = max(size, _INIT_SIZE);
      _bytes = new Uint8List(size);
    }
  }

  int get length => _length;

  int get capacity => _bytes != null ? _bytes.length : 0;

  int get position => _off;

  void clear() {
    _bytes = null;
    _length = 0;
    _wmark = 0;
    _off = 0;
    _rmark = 0;
  }

  void mark() {
    _wmark = _length;
    _rmark = _off;
  }

  void reset() {
    _length = _wmark;
    _off = _rmark;
  }

  void writeByte(int byte) {
    _grow(1);
    _bytes[_length++] = byte;
  }

  void write(List<int> data) {
    int n = data.length;
    if (n == 0) return;
    _grow(n);
    int end = n + _length;
    if (data is Uint8List) {
      _bytes.setRange(_length, end, data);
    } else {
      for (int i = 0; i < n; i++) {
        _bytes[_length + i] = data[i];
      }
    }
    _length = end;
  }

  void writeString(String string) {
    int n = string.length;
    if (n == 0) return;
    // A single code unit uses at most 3 bytes. Two code units at most 4.
    _grow(n * 3);
    for (int i = 0; i < n; i++) {
      int codeUnit = string.codeUnitAt(i);
      if (codeUnit < 0x80) {
        _bytes[_length++] = codeUnit;
      } else if (codeUnit < 0x800) {
        _bytes[_length++] = 0xC0 | (codeUnit >> 6);
        _bytes[_length++] = 0x80 | (codeUnit & 0x3F);
      } else if (codeUnit < 0xD800 || codeUnit > 0xDfff) {
        _bytes[_length++] = 0xE0 | (codeUnit >> 12);
        _bytes[_length++] = 0x80 | ((codeUnit >> 6) & 0x3F);
        _bytes[_length++] = 0x80 | (codeUnit & 0x3F);
      } else {
        if (i + 1 < n) {
          int nextCodeUnit = string.codeUnitAt(i + 1);
          if (codeUnit < 0xDC00 && 0xDC00 <= nextCodeUnit && nextCodeUnit <= 0xDFFF) {
            int rune = (((codeUnit & 0xDC00) << 10) | (nextCodeUnit & 0x03FF)) + 0x010000;
            _bytes[_length++] = 0xF0 | ((rune >> 18) & 0x3F);
            _bytes[_length++] = 0x80 | ((rune >> 12) & 0x3F);
            _bytes[_length++] = 0x80 | ((rune >> 6) & 0x3F);
            _bytes[_length++] = 0x80 | (rune & 0x3F);
            i++;
            continue;
          }
        }
        throw new FormatException("Malformed string");
      }
    }
  }

  int readByte() {
    if (_off < _length) {
      return _bytes[_off++];
    }
    return -1;
  }

  Uint8List read(int n) {
    if (_off + n > _length) {
      n = _length - _off;
    }
    if (n == 0) return _EMPTY_BYTES;
    return new Uint8List.fromList(_bytes.sublist(_off, _off += n));
  }

  int skip(int n) {
    if (_off + n > _length) {
      n = _length - _off;
      _off = _length;
    } else {
      _off += n;
    }
    return n;
  }

  // the result includes tag.
  Uint8List readBytes(int tag) {
    int pos = _bytes.indexOf(tag, _off);
    Uint8List buf;
    if (pos == -1) {
      buf = _bytes.sublist(_off, _length);
      _off = _length;
    } else {
      buf = _bytes.sublist(_off, pos + 1);
      _off = pos + 1;
    }
    return buf;
  }

  // the result doesn't include tag. but the position is the same as readBytes
  String readUntil(int tag) {
    int pos = _bytes.indexOf(tag, _off);
    String str = '';
    if (pos == _off) {
      _off++;
    } else if (pos == -1) {
      str = const Utf8Decoder().convert(_bytes.sublist(_off, _length));
      _off = _length;
    } else {
      str = const Utf8Decoder().convert(_bytes.sublist(_off, pos));
      _off = pos + 1;
    }
    return str;
  }

  String readAsciiString(int n) {
    if (_off + n > _length) {
      n = _length - _off;
    }
    if (n == 0) return "";
    return const AsciiDecoder().convert(_bytes.sublist(_off, _off += n));
  }

  // length is the UTF16 length
  String readString(int n) {
    if (n == 0) return "";
    Uint16List charCodes = new Uint16List(n);
    int i = 0;
    for ( ; i < n && _off < _length; i++) {
      int unit = _bytes[_off++];
      switch (unit >> 4) {
        case 0:
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
          charCodes[i] = unit;
          break;
        case 12:
        case 13:
          if (_off < _length) {
            charCodes[i] = ((unit & 0x1F) << 6) | (_bytes[_off++] & 0x3F);
          } else {
            throw new FormatException("Unfinished UTF-8 octet sequence");
          }
          break;
        case 14:
          if (_off + 1 < _length) {
            charCodes[i] = ((unit & 0x0F) << 12) | ((_bytes[_off++] & 0x3F) << 6) | (_bytes[_off++] & 0x3F);
          } else {
            throw new FormatException("Unfinished UTF-8 octet sequence");
          }
          break;
        case 15:
          if (_off + 2 < _length) {
            int rune = ((unit & 0x07) << 18) | ((_bytes[_off++] & 0x3F) << 12) | ((_bytes[_off++] & 0x3F) << 6) | (_bytes[_off++] & 0x3F) - 0x10000;
            if (0 <= rune && rune <= 0xFFFFF) {
              charCodes[i++] = (((rune >> 10) & 0x03FF) | 0xD800);
              charCodes[i] = ((rune & 0x03FF) | 0xDC00);
            } else {
              throw new FormatException("Character outside valid Unicode range: " "0x${rune.toRadixString(16)}");
            }
          } else {
            throw new FormatException("Unfinished UTF-8 octet sequence");
          }
          break;
        default:
          throw new FormatException("Bad UTF-8 encoding 0x${unit.toRadixString(16)}");
      }
    }
    if (i < n) {
      charCodes = charCodes.sublist(0, i);
    }
    return new String.fromCharCodes(charCodes);
  }

  Uint8List get bytes => (_bytes == null) ? _EMPTY_BYTES : _bytes.sublist(0, _length);

  // returns a view of the the internal buffer and clears `this`.
  Uint8List takeBytes() {
    var buffer = bytes;
    clear();
    return buffer;
  }

  // returns a copy of the current contents and leaves `this` intact.
  Uint8List toBytes() {
    return new Uint8List.fromList(bytes);
  }

  String toString() {
    if (_length == 0) return "";
    return const Utf8Decoder().convert(bytes);
  }

  BytesIO clone() {
    return new BytesIO(toBytes());
  }

  BytesIO([Uint8List this._bytes]) {
    if (_bytes != null) {
      _length = _bytes.length;
    }
  }

  BytesIO.fromByteBuffer(ByteBuffer buffer, [int offsetInBytes = 0, int length]) {
    if (buffer != null) {
      _bytes = buffer.asUint8List(offsetInBytes, length);
      _length = _bytes.length;
    }
  }

  BytesIO.fromString(String string) {
    writeString(string);
  }
}
