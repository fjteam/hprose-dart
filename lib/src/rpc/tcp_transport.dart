/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| tcp_transport.dart                                       |
|                                                          |
| TcpTransport for Dart.                                   |
|                                                          |
| LastModified: Dec 31, 2019                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc;

class TcpTransport implements Transport {
  var _counter = 0;
  final _results = <Socket, Map<int, Completer<Uint8List>>>{};
  final _sockets = <Uri?, Socket>{};
  var noDelay = true;
  SecurityContext? securityContext;
  bool Function(X509Certificate certificate) onBadCertificate = (_) => true;

  Future<Socket> _connect(Uri uri, Duration? timeout) async {
    switch (uri.scheme) {
      case 'tcp':
      case 'tls':
      case 'ssl':
      case 'tcp4':
      case 'tls4':
      case 'ssl4':
      case 'tcp6':
      case 'tls6':
      case 'ssl6':
        break;
      default:
        throw Exception('unsupported ${uri.scheme} protocol');
    }
    var host;
    if (uri.scheme.endsWith('4')) {
      host = (await InternetAddress.lookup(uri.host,
              type: InternetAddressType.IPv4))
          .first;
    } else if (uri.scheme.endsWith('6')) {
      host = (await InternetAddress.lookup(uri.host,
              type: InternetAddressType.IPv6))
          .first;
    } else {
      host = uri.host;
    }
    var port = uri.port == 0 ? 8412 : uri.port;
    if (uri.scheme.startsWith('tcp')) {
      return await Socket.connect(host, port, timeout: timeout);
    }
    return await SecureSocket.connect(host, port,
        context: securityContext,
        onBadCertificate: onBadCertificate,
        timeout: timeout);
  }

  void _close(Uri? uri, Socket socket, Object error) async {
    if (_sockets.containsKey(uri) && _sockets[uri] == socket) {
      _sockets.remove(uri);
    }
    if (_results.containsKey(socket)) {
      var results = _results.remove(socket)!;
      for (var result in results.values) {
        if (!result.isCompleted) {
          result.completeError(error);
        }
      }
    }
  }

  void Function(List<int>) _receive(Uri? uri, Socket socket) {
    final instream = ByteStream();
    const headerLength = 12;
    var bodyLength = -1;
    var index = 0;
    return (List<int> data) async {
      instream.write(data);
      while (true) {
        if ((bodyLength < 0) && (instream.length >= headerLength)) {
          final crc = instream.readUInt32BE();
          instream.mark();
          final header = instream.read(8);
          if (crc32(header) != crc || (header[0] & 0x80) == 0) {
            _close(uri, socket, Exception('Invalid response'));
            socket.destroy();
            return;
          }
          instream.reset();
          bodyLength = instream.readUInt32BE() & 0x7FFFFFFF;
          index = instream.readUInt32BE();
        }
        if ((bodyLength >= 0) &&
            ((instream.length - headerLength) >= bodyLength)) {
          final response = instream.read(bodyLength);
          instream.trunc();
          bodyLength = -1;
          final has_error = (index & 0x80000000) != 0;
          index &= 0x7FFFFFFF;
          if (_results.containsKey(socket)) {
            final results = _results[socket]!;
            final result = results.remove(index);
            if (has_error) {
              if (result != null && !result.isCompleted) {
                result.completeError(Exception(utf8.decode(response)));
              }
              _close(uri, socket, SocketException.closed());
              socket.destroy();
              return;
            } else if (result != null && !result.isCompleted) {
              result.complete(response);
            }
          }
        } else {
          break;
        }
      }
    };
  }

  Future<Socket?> _getSocket(Uri? uri, Duration? timeout) async {
    if (_sockets.containsKey(uri)) {
      return _sockets[uri];
    }
    final socket = await _connect(uri!, timeout);
    socket.setOption(SocketOption.tcpNoDelay, noDelay);
    socket.listen(_receive(uri, socket), onError: (error) {
      _close(uri, socket, error);
    }, onDone: () {
      _close(uri, socket, SocketException.closed());
    }, cancelOnError: true);
    _sockets[uri] = socket;
    return socket;
  }

  @override
  Future<Uint8List> transport(Uint8List request, Context context) async {
    final clientContext = context as ClientContext;
    final uri = clientContext.uri;
    final index = (_counter < 0x7FFFFFFF) ? ++_counter : _counter = 0;
    final result = Completer<Uint8List>();
    final socket = await (_getSocket(uri, clientContext.timeout) as FutureOr<Socket>);
    if (!_results.containsKey(socket)) {
      _results[socket] = {};
    }
    final results = _results[socket]!;
    results[index] = result;
    Timer? timer;
    if (clientContext.timeout! > Duration.zero) {
      timer = Timer(clientContext.timeout!, () async {
        if (!result.isCompleted) {
          result.completeError(TimeoutException('Timeout'));
          await abort();
        }
      });
    }
    final n = request.length;
    final header = Uint8List(12);
    final view = ByteData.view(header.buffer);
    view.setUint32(4, n | 0x80000000, Endian.big);
    view.setUint32(8, index, Endian.big);
    final crc = crc32(header.sublist(4, 12));
    view.setUint32(0, crc, Endian.big);
    socket.add(header + request);
    try {
      return await result.future;
    } finally {
      timer?.cancel();
    }
  }

  @override
  Future<void> abort() async {
    final sockets = Map<Uri, Socket>.from(_sockets);
    _sockets.clear();
    sockets.forEach((uri, socket) {
      _close(uri, socket, SocketException.closed());
      socket.close();
    });
  }
}

class TcpTransportCreator implements TransportCreator<TcpTransport> {
  @override
  List<String>? schemes = [
    'tcp',
    'tcp4',
    'tcp6',
    'tls',
    'tls4',
    'tls6',
    'ssl',
    'ssl4',
    'ssl6'
  ];

  @override
  TcpTransport create() {
    return TcpTransport();
  }
}
