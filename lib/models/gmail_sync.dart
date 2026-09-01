import 'package:cloud_firestore/cloud_firestore.dart';

enum GmailConnectionStatus {
  none('none', 'Not connected'),
  connected('connected', 'Connected'),
  expired('expired', 'Reconnect needed'),
  needsReconnect('needs_reconnect', 'Disconnected'),
  error('error', 'Connection problem');

  const GmailConnectionStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static GmailConnectionStatus fromWire(Object? value) {
    return GmailConnectionStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => GmailConnectionStatus.none,
    );
  }
}

class GmailSync {
  const GmailSync({
    this.status = GmailConnectionStatus.none,
    this.historyId,
    this.watchExpiration,
    this.connectedAt,
    this.lastError,
    this.lastSyncedAt,
  });

  final GmailConnectionStatus status;
  final String? historyId;
  final DateTime? watchExpiration;
  final DateTime? connectedAt;
  final String? lastError;
  final DateTime? lastSyncedAt;

  bool get isConnected => status == GmailConnectionStatus.connected;

  bool get hasEverConnected => status != GmailConnectionStatus.none;

  bool get needsReconnect =>
      status == GmailConnectionStatus.needsReconnect ||
      status == GmailConnectionStatus.expired;

  bool isStale(DateTime now, {Duration threshold = const Duration(hours: 6)}) {
    if (!isConnected || lastSyncedAt == null) {
      return false;
    }
    return now.difference(lastSyncedAt!.toLocal()) > threshold;
  }

  factory GmailSync.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const GmailSync();
    }
    return GmailSync(
      status: GmailConnectionStatus.fromWire(map['status']),
      historyId: map['historyId']?.toString(),
      watchExpiration: _toDate(map['watchExpiration']),
      connectedAt: _toDate(map['connectedAt']),
      lastError: map['lastError'] as String?,
      lastSyncedAt: _toDate(map['lastSyncedAt']),
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
