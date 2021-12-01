/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| string_serializer.ts                                     |
|                                                          |
| hprose String Serializer for Dart.                       |
|                                                          |
| LastModified: Dec 31, 2019                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.io;

class StringSerializer extends ReferenceSerializer<String?> {
  static final AbstractSerializer<String?> instance = StringSerializer();
  @override
  void write(Writer writer, String? value) {
    super.write(writer, value);
    final stream = writer.stream;
    stream.writeByte(TagString);
    ValueWriter.writeStringBody(stream, value!);
  }

  @override
  void serialize(Writer writer, String? value) {
    final stream = writer.stream;
    switch (value!.length) {
      case 0:
        stream.writeByte(TagEmpty);
        break;
      case 1:
        stream.writeByte(TagUTF8Char);
        stream.writeString(value);
        break;
      default:
        super.serialize(writer, value);
        break;
    }
  }
}
