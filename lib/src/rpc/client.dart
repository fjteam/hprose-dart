/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| client.dart                                              |
|                                                          |
| Client for Dart.                                         |
|                                                          |
| LastModified: Dec 31, 2019                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc;

class Client extends core.Client {
  static void register<T extends Transport>(
      String name, TransportCreator<T> creator) {
    core.Client.register<T>(name, creator);
  }

  static bool isRegister(String name) {
    return core.Client.isRegister(name);
  }

  Client([List<String>? uris]) : super(uris);
  HttpTransport? get http => this['http'] as HttpTransport?;
  TcpTransport? get tcp => this['tcp'] as TcpTransport?;
  UdpTransport? get udp => this['udp'] as UdpTransport?;
  WebSocketTransport? get websocket => this['websocket'] as WebSocketTransport?;

  @override
  void init() {
    super.init();
    if (!isRegister('http')) {
      register<HttpTransport>('http', HttpTransportCreator());
    }
    if (!isRegister('tcp')) {
      register<TcpTransport>('tcp', TcpTransportCreator());
    }
    if (!isRegister('udp')) {
      register<UdpTransport>('udp', UdpTransportCreator());
    }
    if (!isRegister('websocket')) {
      register<WebSocketTransport>('websocket', WebSocketTransportCreator());
    }
  }
}
