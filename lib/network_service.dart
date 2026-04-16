import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class NetworkService {
  String? serverIp;
  int serverPort = 3000;
  String? token;
  String? clientId;

  Future<void> init(String storedClientId) async {
    clientId = storedClientId;
  }

  // Auto-detect server using UDP broadcast
  Future<String?> discoverServer() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      
      final msg = utf8.encode(jsonEncode({"type": "DISCOVER_PHARMACORE_SERVER"}));
      socket.send(msg, InternetAddress("255.255.255.255"), 4000);
      
      String? foundIp;
      
      await for (RawSocketEvent event in socket.timeout(const Duration(seconds: 2), onTimeout: (e) {
        socket.close();
      })) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final data = utf8.decode(datagram.data);
            final json = jsonDecode(data);
            if (json["type"] == "PHARMACORE_SERVER_ANNOUNCEMENT" && json["identity"] != null) {
              foundIp = datagram.address.address;
              serverPort = json["httpPort"] ?? 3000;
              socket.close();
              break;
            }
          }
        }
      }
      return foundIp;
    } catch (_) {
      return null;
    }
  }

  Future<bool> connectManual(String ip, int port) async {
    try {
      final url = Uri.parse("http://$ip:$port/api/status");
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["identity"] != null) {
          serverIp = ip;
          serverPort = port;
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    if (serverIp == null) return false;
    final url = Uri.parse("http://$serverIp:$serverPort/api/auth/login");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data["token"];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>?> pullOperations(int lastSeqId) async {
    if (serverIp == null || token == null) return null;
    final url = Uri.parse("http://$serverIp:$serverPort/api/sync/pull?last_seq_id=$lastSeqId");
    try {
      final response = await http.get(url, headers: {
        "Authorization": "Bearer $token"
      }).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["operations"];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> pushOperations(List<Map<String, dynamic>> operations) async {
    if (serverIp == null || token == null || clientId == null) return false;
    if (operations.isEmpty) return true;
    
    final url = Uri.parse("http://$serverIp:$serverPort/api/sync/push");
    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "clientId": clientId,
          "operations": operations,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
