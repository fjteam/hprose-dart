/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| jsonrpc_service_codec.dart                               |
|                                                          |
| JsonRpcServiceCodec for Dart.                            |
|                                                          |
| LastModified: Mar 28, 2020                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc.codec.jsonrpc;

class JsonRpcServiceCodec implements ServiceCodec {
  static JsonRpcServiceCodec instance = JsonRpcServiceCodec();

  @override
  Uint8List encode(result, ServiceContext context) {
    if (!context['jsonrpc']) {
      return DefaultServiceCodec.instance.encode(result, context);
    }
    final response = {'jsonrpc': '2.0', 'id': context['jsonrpc.id']};
    if (context.responseHeaders.isNotEmpty) {
      response['headers'] = context.responseHeaders;
    }
    if (result is FormatException) {
      response['error'] = <String, dynamic>{
        'code': -32700,
        'message': 'Parse error'
      };
    } else if (result is Error || result is Exception) {
      try {
        switch (result.message) {
          case 'Invalid Request':
            response['error'] = <String, dynamic>{
              'code': -32600,
              'message': 'Invalid Request'
            };
            break;
          case 'Method not found':
            response['error'] = <String, dynamic>{
              'code': -32601,
              'message': 'Method not found'
            };
            break;
          case 'Invalid params':
            response['error'] = <String, dynamic>{
              'code': -32602,
              'message': 'Invalid params'
            };
            break;
          default:
            response['error'] = <String, dynamic>{
              'code': 0,
              'message': result.message
            };
            if (result is Error) {
              response['error']['data'] = result.stackTrace.toString();
            } else {
              response['error']['data'] = result.toString();
            }
        }
      } catch (e) {
        response['error'] = <String, dynamic>{
          'code': 0,
          'message': result.toString()
        };
        if (result is Error) {
          response['error']['data'] = result.stackTrace.toString();
        }
      }
    } else {
      response['result'] = result;
    }
    return utf8.encode(json.encode(response)) as Uint8List;
  }

  @override
  RequestInfo decode(Uint8List request, ServiceContext context) {
    context['jsonrpc'] = (request.isNotEmpty && request[0] == TagOpenbrace);
    if (!context['jsonrpc']) {
      return DefaultServiceCodec.instance.decode(request, context);
    }
    final Map<String, dynamic> call = json.decode(utf8.decode(request));
    if (call['jsonrpc'] != '2.0' ||
        !call.containsKey('method') ||
        !call.containsKey('id')) {
      throw Exception('Invalid Request');
    }
    if (call.containsKey('headers')) {
      context.requestHeaders.addAll(call['headers']);
    }
    context['jsonrpc.id'] = call['id'];
    final name = call['method'];
    final method = context.service.get(name);
    if (method == null) {
      throw Exception('Method not found');
    }
    context.method = method;
    final args =
        call.containsKey('params') ? call['params'].toList(growable: true) : [];
    if (!method.missing) {
      var count = args.length;
      var ppl = method.positionalParameterTypes.length;
      if (count < ppl) {
        args.length = ppl;
      }
      var opl = method.optionalParameterTypes.length;
      var n = ppl + opl;
      if (method.hasOptionalArguments) {
        if (count < ppl) {
          n = ppl;
        } else if (count < n) {
          n = count;
        }
      }
      if (method.hasNamedArguments) {
        n = ppl + 1;
      }
      if (method.contextInPositionalArguments) {
        ppl--;
        n--;
      }
      n = min(count, n);
      args.length = n;
      for (var i = 0; i < n; ++i) {
        if (i < ppl) {
          args[i] = Formatter.deserialize(Formatter.serialize(args[i]),
              type: method.positionalParameterTypes[i]);
        } else if (method.hasOptionalArguments) {
          args[i] = Formatter.deserialize(Formatter.serialize(args[i]),
              type: method.optionalParameterTypes[i - ppl]);
        }
        if (i == ppl && method.hasNamedArguments) {
          if (args[i] is! Map) {
            throw Exception('Invalid params');
          }
          var originalNamedArgs = (args[i] as Map);
          var namedArgs = <Symbol, dynamic>{};
          for (final entry in originalNamedArgs.entries) {
            var key = entry.key.toString();
            if (method.namedParameterTypes.containsKey(key)) {
              var value = Formatter.deserialize(
                  Formatter.serialize(entry.value),
                  type: method.namedParameterTypes[key]);
              namedArgs[Symbol(key)] = value;
            }
          }
          args[i] = namedArgs;
        }
      }
    }
    return RequestInfo(name, args);
  }
}
