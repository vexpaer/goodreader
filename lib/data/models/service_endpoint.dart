/// 用户自带服务。每个能力都通过抽象的「端点」接入，用户自己填地址与密钥。
///
/// 设计要点。端点描述「连哪、用什么连」，不描述「连了之后做什么」。
/// 请求构造、错误映射、重试放在各自的客户端里，端点只做寻址与凭据。
library;

/// 端点提供的能力。枚举值与持久化下标绑定，新增只能追加到末尾。
enum ServiceKind {
  /// 大模型对话，OpenAI 兼容协议。
  ai,

  /// 云同步，WebDAV 或 S3。
  sync,

  /// 文字识别，HTTP 服务或端上模型。
  ocr,

  /// 语音合成，用于听书。
  tts,

  /// 书源，抓取网络书目。
  bookSource,
}

extension ServiceKindLabel on ServiceKind {
  String get label => switch (this) {
        ServiceKind.ai => 'AI 助手',
        ServiceKind.sync => '云同步',
        ServiceKind.ocr => '文字识别',
        ServiceKind.tts => '语音合成',
        ServiceKind.bookSource => '书源',
      };

  String get shortLabel => switch (this) {
        ServiceKind.ai => 'AI',
        ServiceKind.sync => '同步',
        ServiceKind.ocr => 'OCR',
        ServiceKind.tts => 'TTS',
        ServiceKind.bookSource => '书源',
      };
}

/// 一个用户配置好的服务端点。
///
/// [secret] 单独存放，不随端点记录一起导出或同步。 UI 一律显示脱敏值。
class ServiceEndpoint {
  ServiceEndpoint({
    required this.id,
    required this.kind,
    required this.label,
    required this.baseUrl,
    this.secret = '',
    this.model = '',
    this.enabled = true,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final ServiceKind kind;

  /// 用户给这个端点起的名字，例如「公司的 DeepSeek」。
  String label;
  final String baseUrl;

  /// 密钥或令牌。单独存放，仅在构造请求时读取。
  String secret;

  /// 默认模型或配置档，留空由客户端决定。
  String model;
  bool enabled;

  /// 用户备注，例如「这个有免费额度」。
  String note;
  final DateTime createdAt;

  bool get needsSecret => true;

  /// 归一化的地址。去掉末尾斜杠，补上缺失的协议。
  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  ServiceEndpoint copyWith({
    String? label,
    String? baseUrl,
    String? secret,
    String? model,
    bool? enabled,
    String? note,
  }) =>
      ServiceEndpoint(
        id: id,
        kind: kind,
        label: label ?? this.label,
        baseUrl: baseUrl ?? this.baseUrl,
        secret: secret ?? this.secret,
        model: model ?? this.model,
        enabled: enabled ?? this.enabled,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.index,
        'label': label,
        'baseUrl': baseUrl,
        'model': model,
        'enabled': enabled,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  /// 读回一条端点。坏数据返回 null，由调用方跳过。
  static ServiceEndpoint? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    final baseUrl = raw['baseUrl'];
    final kindIndex = raw['kind'];
    if (id is! String || label is! String || baseUrl is! String) return null;
    if (kindIndex is! int || kindIndex < 0 || kindIndex >= ServiceKind.values.length) {
      return null;
    }
    final createdAt = raw['createdAt'];
    return ServiceEndpoint(
      id: id,
      kind: ServiceKind.values[kindIndex],
      label: label,
      baseUrl: baseUrl,
      model: raw['model'] is String ? raw['model'] as String : '',
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      note: raw['note'] is String ? raw['note'] as String : '',
      createdAt: createdAt is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : DateTime.now(),
    );
  }
}

/// 目录里的一个预置选项。用户选中后只需补地址与密钥。
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.name,
    required this.kind,
    required this.defaultBaseUrl,
    this.models = const [],
    this.hint = '',
    this.secretLabel = 'API Key',
  });

  final String id;
  final String name;
  final ServiceKind kind;

  /// 预置地址，留空表示由用户自己填。
  final String defaultBaseUrl;

  /// 常见模型或配置档，仅作输入建议。
  final List<String> models;

  /// 一句话说明，显示在选择列表里。
  final String hint;

  /// 密钥输入框的标签。
  final String secretLabel;
}

/// 把密钥显示成脱敏形式。只留首尾各两位，中间按长度补星号。
String maskSecret(String secret) {
  final trimmed = secret.trim();
  if (trimmed.isEmpty) return '未填写';
  if (trimmed.length <= 4) return '****';
  final head = trimmed.substring(0, 2);
  final tail = trimmed.substring(trimmed.length - 2);
  final stars = '*' * (trimmed.length - 4).clamp(2, 12);
  return '$head$stars$tail';
}
