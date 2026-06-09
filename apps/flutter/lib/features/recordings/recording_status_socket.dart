import 'dart:async';

import 'package:phoenix_socket/phoenix_socket.dart';

import '../../core/http/token_store.dart';
import 'recording_status_event.dart';

/// Derives the Phoenix socket endpoint from an HTTP(S) API base URL.
///
/// `http://host:4000` -> `ws://host:4000/socket/websocket`
/// `https://host`     -> `wss://host/socket/websocket`
///
/// phoenix_socket appends `vsn=2.0.0` and the connection params itself.
Uri buildSocketEndpoint(String apiBaseUrl) {
  final base = Uri.parse(apiBaseUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return base.replace(
    scheme: scheme,
    path: '/socket/websocket',
    query: '',
  );
}

/// Wraps a [PhoenixSocket] joined to the `user:{ownerId}` channel and surfaces
/// the `recording:status` push events as a typed stream.
///
/// Token rotation (#764 auto-refresh) is handled via `dynamicParams`:
/// phoenix_socket calls it before *every* (re)connect attempt, so each socket
/// (re)connection picks up the freshest access token from the [TokenStore].
class RecordingStatusSocket {
  RecordingStatusSocket({
    required String apiBaseUrl,
    required TokenStore tokenStore,
    required int ownerId,
    PhoenixSocket Function(String endpoint, PhoenixSocketOptions options)?
        socketFactory,
  })  : _ownerId = ownerId,
        _topic = 'user:$ownerId',
        _socket = (socketFactory ?? _defaultFactory)(
          buildSocketEndpoint(apiBaseUrl).toString(),
          PhoenixSocketOptions(
            // Pulled fresh on each (re)connect — survives token rotation.
            dynamicParams: () async {
              final token = await tokenStore.readAccessToken();
              if (token == null || token.isEmpty) return const <String, String>{};
              return <String, String>{'token': token};
            },
          ),
        );

  static PhoenixSocket _defaultFactory(
    String endpoint,
    PhoenixSocketOptions options,
  ) =>
      PhoenixSocket(endpoint, socketOptions: options);

  final int _ownerId;
  final String _topic;
  final PhoenixSocket _socket;

  PhoenixChannel? _channel;
  StreamSubscription<Message>? _sub;
  final _events = StreamController<RecordingStatusEvent>.broadcast();

  int get ownerId => _ownerId;

  /// Broadcast stream of parsed `recording:status` events for this owner.
  Stream<RecordingStatusEvent> get events => _events.stream;

  /// Connects the socket and joins `user:{ownerId}`.
  ///
  /// Returns `true` when the channel join is acknowledged with `status: ok`.
  /// Throws [RecordingSocketException] when the channel rejects the join
  /// (e.g. `unauthorized`) — surfaced so the de-risk path fails loudly rather
  /// than silently falling back to polling on an auth error.
  Future<bool> connectAndJoin() async {
    final connected = await _socket.connect();
    if (connected == null) {
      throw const RecordingSocketException('socket_connect_failed');
    }

    final channel = _socket.addChannel(topic: _topic);
    _channel = channel;

    _sub = channel.messages.listen(_onMessage);

    final reply = await channel.join().future;
    if (!reply.isOk) {
      final reason = reply.response is Map
          ? (reply.response as Map)['reason']?.toString()
          : null;
      throw RecordingSocketException(reason ?? 'channel_join_failed');
    }
    return true;
  }

  void _onMessage(Message message) {
    if (message.event.value != 'recording:status') return;
    final parsed = RecordingStatusEvent.tryParse(message.payload);
    if (parsed != null) _events.add(parsed);
  }

  /// Leaves the channel and tears down the socket + streams.
  Future<void> dispose() async {
    await _sub?.cancel();
    _channel?.leave();
    _socket.close();
    if (!_events.isClosed) await _events.close();
  }
}

/// Raised when the socket cannot connect or the channel rejects the join.
class RecordingSocketException implements Exception {
  const RecordingSocketException(this.reason);
  final String reason;
  @override
  String toString() => 'RecordingSocketException($reason)';
}
