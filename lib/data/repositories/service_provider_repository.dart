import 'dart:convert';

import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../models/service_endpoint.dart';

/// 服务端点的增删改查，以及「每种能力当前用哪个」的选取。
///
/// 端点记录与密钥**分开存放**。端点记录随备份导出，密钥不参与导出也不参与
/// 同步，所以把库分享给别人不会泄露密钥。这不是防 root 的加密，只是让密钥
/// 不会顺着备份和同步流出去。真要防本机读取需要 Keystore，是后续的事。
class ServiceProviderRepository {
  ServiceProviderRepository({
    Box<dynamic>? endpointsBox,
    Box<dynamic>? secretsBox,
  })  : _endpoints = endpointsBox ?? Hive.box<dynamic>(HiveBoxes.serviceEndpoints),
        _secrets = secretsBox ?? Hive.box<dynamic>(HiveBoxes.serviceSecrets);

  final Box<dynamic> _endpoints;
  final Box<dynamic> _secrets;

  static const _itemsKey = 'items';
  static const _activePrefix = 'active-';

  List<ServiceEndpoint> load() =>
      ServiceEndpointCodec.decodeAll(_endpoints.get(_itemsKey));

  Future<void> save(List<ServiceEndpoint> endpoints) =>
      _endpoints.put(_itemsKey, ServiceEndpointCodec.encodeAll(endpoints));

  /// 每种能力当前启用的端点 id。值为 null 或指向不存在的 id 表示未配置。
  Map<ServiceKind, String> loadActive() {
    final out = <ServiceKind, String>{};
    for (final kind in ServiceKind.values) {
      final raw = _endpoints.get('$_activePrefix${kind.index}');
      if (raw is String && raw.isNotEmpty) out[kind] = raw;
    }
    return out;
  }

  Future<void> setActive(ServiceKind kind, String? endpointId) {
    if (endpointId == null) {
      return _endpoints.delete('$_activePrefix${kind.index}');
    }
    return _endpoints.put('$_activePrefix${kind.index}', endpointId);
  }

  ServiceEndpoint? activeOf(ServiceKind kind) {
    final active = loadActive()[kind];
    if (active == null) return null;
    for (final endpoint in load()) {
      if (endpoint.id == active && endpoint.enabled) return endpoint;
    }
    return null;
  }

  /// 新建一个端点。id 由种类加时间戳生成，同一毫秒内不会重复。
  ServiceEndpoint create({
    required ServiceKind kind,
    required String label,
    required String baseUrl,
    String secret = '',
    String model = '',
    String note = '',
  }) {
    final endpoint = ServiceEndpoint(
      id: 'ep-${kind.index}-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      label: label,
      baseUrl: baseUrl,
      model: model,
      note: note,
    );
    if (secret.isNotEmpty) writeSecret(endpoint.id, secret);
    return endpoint;
  }

  Future<void> add(ServiceEndpoint endpoint) async {
    final endpoints = load();
    endpoints.removeWhere((e) => e.id == endpoint.id);
    endpoints.add(endpoint);
    await save(endpoints);
    if (endpoint.secret.isNotEmpty) {
      await writeSecret(endpoint.id, endpoint.secret);
    }
  }

  Future<void> update(ServiceEndpoint endpoint) async {
    final endpoints = load();
    final index = endpoints.indexWhere((e) => e.id == endpoint.id);
    if (index < 0) return;
    endpoints[index] = endpoint;
    await save(endpoints);
    if (endpoint.secret.isEmpty) {
      await _secrets.delete(endpoint.id);
    } else if (endpoint.secret != readSecret(endpoint.id)) {
      await writeSecret(endpoint.id, endpoint.secret);
    }
  }

  Future<void> remove(String id) async {
    await save(load().where((e) => e.id != id).toList());
    await _secrets.delete(id);
    final active = loadActive();
    for (final entry in active.entries) {
      if (entry.value == id) await setActive(entry.key, null);
    }
  }

  String readSecret(String endpointId) {
    final raw = _secrets.get(endpointId);
    return raw is String ? raw : '';
  }

  Future<void> writeSecret(String endpointId, String secret) async {
    if (secret.isEmpty) {
      await _secrets.delete(endpointId);
      return;
    }
    await _secrets.put(endpointId, secret);
  }

  /// 导出用。带上密钥，用户显式选择导出时才调。
  Map<String, dynamic> exportWithSecrets() => {
        'endpoints': ServiceEndpointCodec.decodeToMaps(load()),
        'secrets': {
          for (final endpoint in load())
            if (readSecret(endpoint.id).isNotEmpty)
              endpoint.id: readSecret(endpoint.id),
        },
      };

  /// 备份用。只含端点记录，**绝不含密钥**。
  List<Map<String, dynamic>> exportForBackup() =>
      ServiceEndpointCodec.decodeToMaps(load());
}

/// 端点记录的编解码。与 `BorderAsset` 的坏数据策略一致：不抛异常，逐条跳过。
class ServiceEndpointCodec {
  const ServiceEndpointCodec._();

  static List<ServiceEndpoint> decodeAll(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ServiceEndpoint.fromMap)
          .whereType<ServiceEndpoint>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static String encodeAll(List<ServiceEndpoint> endpoints) =>
      jsonEncode(endpoints.map((e) => e.toMap()).toList());

  static List<Map<String, dynamic>> decodeToMaps(List<ServiceEndpoint> endpoints) =>
      endpoints.map((e) => e.toMap()).toList(growable: false);
}
