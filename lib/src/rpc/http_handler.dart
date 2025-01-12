/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| http_handler.dart                                        |
|                                                          |
| HttpHandler for Dart.                                    |
|                                                          |
| LastModified: Feb 28, 2020                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc;

class HttpHandler implements Handler<HttpServer> {
  static final _lastModified = DateTime.now().toUtc();
  static final _random = Random.secure();
  static final _etag =
      '"${_random.nextInt(2147483647).toRadixString(16)}:${_random.nextInt(2147483647).toRadixString(16)}"';

  var p3p = true;
  var get = true;
  var crossDomain = true;
  var httpHeaders = <String, Object>{};
  final _origins = <String, bool>{};
  var _crossDomainXmlFile = '';
  var _crossDomainXmlContent = '';
  var _clientAccessPolicyXmlFile = '';
  var _clientAccessPolicyXmlContent = '';
  String get crossDomainXmlFile => _crossDomainXmlFile;
  set crossDomainXmlFile(String value) {
    _crossDomainXmlFile = value;
    _crossDomainXmlContent = File(value).readAsStringSync();
  }

  String get clientAccessPolicyXmlFile => _clientAccessPolicyXmlFile;
  set clientAccessPolicyXmlFile(String value) {
    _clientAccessPolicyXmlFile = value;
    _clientAccessPolicyXmlContent = File(value).readAsStringSync();
  }

  String get crossDomainXmlContent => _crossDomainXmlContent;
  set crossDomainXmlContent(String value) {
    _crossDomainXmlFile = '';
    _crossDomainXmlContent = value;
  }

  String get clientAccessPolicyXmlContent => _clientAccessPolicyXmlContent;
  set clientAccessPolicyXmlContent(String value) {
    _clientAccessPolicyXmlFile = '';
    _clientAccessPolicyXmlContent = value;
  }

  void Function(dynamic error)? onError;
  void Function()? onDone;
  core.Service service;
  HttpHandler(this.service);

  @override
  void bind(HttpServer server) {
    server.listen((request) async {
      final context = getContext(request);
      context['server'] = server;
      context.localAddress = server.address;
      context.host = server.address.host;
      await handler(request, context);
    }, onError: onError, onDone: onDone);
  }

  bool _crossDomainXmlHandler(HttpRequest request) {
    if (request.uri.path.toLowerCase() == '/crossdomain.xml') {
      final response = request.response;
      if (request.headers.ifModifiedSince == _lastModified &&
          request.headers.value(HttpHeaders.ifNoneMatchHeader) == _etag) {
        response.statusCode = 304;
      } else {
        response.headers.add(HttpHeaders.lastModifiedHeader, _lastModified);
        response.headers.add(HttpHeaders.etagHeader, _etag);
        response.headers.add(HttpHeaders.contentTypeHeader, 'text/xml');
        response.write(_crossDomainXmlContent);
      }
      return true;
    }
    return false;
  }

  bool _clientAccessPolicyXmlHandler(HttpRequest request) {
    if (request.uri.path.toLowerCase() == '/clientaccesspolicy.xml') {
      final response = request.response;
      if (request.headers.ifModifiedSince == _lastModified &&
          request.headers.value(HttpHeaders.ifNoneMatchHeader) == _etag) {
        response.statusCode = 304;
      } else {
        response.headers.add(HttpHeaders.lastModifiedHeader, _lastModified);
        response.headers.add(HttpHeaders.etagHeader, _etag);
        response.headers.add(HttpHeaders.contentTypeHeader, 'text/xml');
        response.write(_clientAccessPolicyXmlContent);
      }
      return true;
    }
    return false;
  }

  void sendHeader(HttpRequest request, ServiceContext context) {
    final response = request.response;
    if (context.containsKey('httpStatusCode')) {
      response.statusCode = context['httpStatusCode'];
    } else {
      response.statusCode = 200;
    }
    response.headers.add(HttpHeaders.contentTypeHeader, 'text/plain');
    if (p3p) {
      response.headers.add(
          'P3P',
          'CP="CAO DSP COR CUR ADM DEV TAI PSA PSD IVAi IVDi '
              'CONi TELo OTPi OUR DELi SAMi OTRi UNRi PUBi IND PHY ONL '
              'UNI PUR FIN COM NAV INT DEM CNT STA POL HEA PRE GOV"');
    }
    if (crossDomain) {
      final origin = request.headers['origin']?.first;
      if (origin != null && origin != 'null') {
        if (_origins.isEmpty || _origins[origin]!) {
          response.headers.add('Access-Control-Allow-Origin', origin);
          response.headers.add('Access-Control-Allow-Credentials', 'true');
        }
      } else {
        response.headers.add('Access-Control-Allow-Origin', '*');
      }
    }
    if (httpHeaders != null) {
      httpHeaders.forEach(response.headers.add);
    }
    if (context.containsKey('httpResponseHeaders')) {
      (context['httpResponseHeaders'] as Map<String, Object>?)
          ?.forEach(response.headers.add);
    }
  }

  void addAccessControlAllowOrigin(String origin) {
    if (!_origins[origin]!) {
      _origins[origin] = true;
    }
  }

  void removeAccessControlAllowOrigin(String origin) {
    if (_origins[origin]!) {
      _origins.remove(origin);
    }
  }

  void _end(HttpResponse response) async {
    await response.flush();
    await response.close();
  }

  Map<String, Object> getHttpRequestHeaders(HttpRequest request) {
    final httpRequestHeaders = <String, Object>{};
    request.headers.forEach((String name, List<String> values) {
      if (values.length == 1) {
        httpRequestHeaders[name] = values[0];
      } else {
        httpRequestHeaders[name] = values;
      }
    });
    return httpRequestHeaders;
  }

  ServiceContext getContext(HttpRequest request) {
    final response = request.response;
    final context = service.createContext() as ServiceContext;
    context['request'] = request;
    context['response'] = response;
    context['httpRequestHeaders'] = getHttpRequestHeaders(request);
    context.remoteAddress = request.connectionInfo!.remoteAddress;
    context.remotePort = request.connectionInfo!.remotePort;
    context.localPort = request.connectionInfo!.localPort;
    context.handler = this;
    return context;
  }

  void requestHandler(HttpRequest request) async {
    final context = getContext(request);
    await handler(request, context);
  }

  Future handler(HttpRequest request, ServiceContext context) async {
    final response = request.response;
    if (request.contentLength > service.maxRequestLength) {
      response.statusCode = HttpStatus.requestEntityTooLarge;
      response.reasonPhrase = 'Request Entity Too Large';
      _end(response);
      return;
    }
    if (request.method == 'GET') {
      if (_clientAccessPolicyXmlContent.isNotEmpty &&
          _clientAccessPolicyXmlHandler(request)) {
        _end(response);
        return;
      }
      if (_crossDomainXmlContent.isNotEmpty &&
          _crossDomainXmlHandler(request)) {
        _end(response);
        return;
      }
      if (!get) {
        response.statusCode = HttpStatus.forbidden;
        response.reasonPhrase = 'Forbidden';
        _end(response);
        return;
      }
    }
    final stream =
        ByteStream(request.contentLength >= 0 ? request.contentLength : 0);
    await for (var data in request) {
      stream.write(data);
    }
    final data = stream.takeBytes();
    final result = await service.handle(data, context);
    sendHeader(request, context);
    response.contentLength = result.length;
    response.add(result);
    _end(response);
  }
}
