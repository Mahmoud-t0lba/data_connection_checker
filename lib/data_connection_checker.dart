import 'dart:async';
import 'dart:io';

enum DataConnectionStatus { disconnected, connected }

class DataConnectionChecker {
  static const int dProt = 53;

  static const Duration timeOut = Duration(seconds: 10);

  static const Duration dInterval = Duration(seconds: 10);

  static final List<AddressCheckOptions> dAddresses = List.unmodifiable([
    AddressCheckOptions(
      InternetAddress('1.1.1.1'),
      port: dProt,
      timeout: timeOut,
    ),
    AddressCheckOptions(
      InternetAddress('8.8.4.4'),
      port: dProt,
      timeout: timeOut,
    ),
    AddressCheckOptions(
      InternetAddress('208.67.222.222'),
      port: dProt,
      timeout: timeOut,
    ),
  ]);

  List<AddressCheckOptions> addresses = dAddresses;

  factory DataConnectionChecker() => _instance;

  DataConnectionChecker._()
      : _lastStatus = DataConnectionStatus.disconnected,
        _timerHandle = Timer(Duration.zero, () {}) {
    connectionStatus.then((status) => _lastStatus = status);

    _statusController.onListen = _maybeEmitStatusUpdate;

    _statusController.onCancel = () {
      _timerHandle.cancel();
      _lastStatus = _lastStatus;
    };
  }

  static final DataConnectionChecker _instance = DataConnectionChecker._();

  Future<AddressCheckResult> isHostReachable(
    AddressCheckOptions options,
  ) async {
    Socket? sock;
    try {
      sock = await Socket.connect(
        options.address,
        options.port,
        timeout: options.timeout,
      );
      sock.destroy();
      return AddressCheckResult(options, true);
    } catch (e) {
      sock?.destroy();
      return AddressCheckResult(options, false);
    }
  }

  List<AddressCheckResult> get lastTryResults => _lastTryResults;
  List<AddressCheckResult> _lastTryResults = <AddressCheckResult>[];

  Future<bool> get hasConnection async {
    List<Future<AddressCheckResult>> requests = [];

    for (var addressOptions in addresses) {
      requests.add(isHostReachable(addressOptions));
    }
    _lastTryResults = List.unmodifiable(await Future.wait(requests));

    return _lastTryResults.map((result) => result.isSuccess).contains(true);
  }

  Future<DataConnectionStatus> get connectionStatus async {
    return await hasConnection
        ? DataConnectionStatus.connected
        : DataConnectionStatus.disconnected;
  }

  Duration checkInterval = dInterval;

  _maybeEmitStatusUpdate([Timer? timer]) async {
    _timerHandle.cancel();
    timer?.cancel();

    var currentStatus = await connectionStatus;

    if (_lastStatus != currentStatus && _statusController.hasListener) {
      _statusController.add(currentStatus);
    }

    if (!_statusController.hasListener) return;
    _timerHandle = Timer(checkInterval, _maybeEmitStatusUpdate);

    _lastStatus = currentStatus;
  }

  DataConnectionStatus _lastStatus;
  Timer _timerHandle;

  final StreamController<DataConnectionStatus> _statusController =
      StreamController<DataConnectionStatus>.broadcast();

  Stream<DataConnectionStatus> get onStatusChange => _statusController.stream;

  bool get hasListeners => _statusController.hasListener;

  bool get isActivelyChecking => _statusController.hasListener;
}

class AddressCheckOptions {
  final InternetAddress address;
  final int port;
  final Duration timeout;

  AddressCheckOptions(
    this.address, {
    this.port = DataConnectionChecker.dProt,
    this.timeout = DataConnectionChecker.timeOut,
  });

  @override
  String toString() => 'AddressCheckOptions($address, $port, $timeout)';
}

class AddressCheckResult {
  final AddressCheckOptions options;
  final bool isSuccess;

  AddressCheckResult(
    this.options,
    this.isSuccess,
  );

  @override
  String toString() => 'AddressCheckResult($options, $isSuccess)';
}
