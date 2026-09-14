import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';

class KdsWebSocketClient {
  WebSocketChannel? _channel;

  Stream<dynamic>? connect(String areaProduksi) {
    final url = Uri.parse(ApiEndpoints.kdsWs(areaProduksi));
    _channel = WebSocketChannel.connect(url);
    return _channel?.stream;
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
