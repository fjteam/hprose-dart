/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| service.dart                                             |
|                                                          |
| Service for Dart.                                        |
|                                                          |
| LastModified: Dec 31, 2019                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc;

class Service extends core.Service {
  static void register<T extends Handler>(
      String name, HandlerCreator<T> creator) {
    core.Service.register<T>(name, creator);
  }

  static bool isRegister(String name) {
    return core.Service.isRegister(name);
  }

  HttpHandler? get http => this['websocket'] as HttpHandler?;
  TcpHandler? get tcp => this['tcp'] as TcpHandler<Socket>?;
  UdpHandler? get udp => this['udp'] as UdpHandler?;
  WebSocketHandler? get websocket => this['websocket'] as WebSocketHandler?;

  @override
  void init() {
    super.init();
    if (!isRegister('tcp')) {
      register<TcpHandler>('tcp', TcpHandlerCreator());
    }
    if (!isRegister('udp')) {
      register<UdpHandler>('udp', UdpHandlerCreator());
    }
    if (!isRegister('websocket')) {
      register<WebSocketHandler>('websocket', WebSocketHandlerCreator());
    }
  }

  @override
  ServiceContext createContext() => ServiceContext(this);
}
