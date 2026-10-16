import 'package:goodreader/services/http_transport.dart';

/// 一轮对话里的一条消息。
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.model,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// `user` 或 `assistant`。
  final String role;
  String content;

  /// 产生这条回复的模型，仅 assistant 消息有。
  String? model;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  Map<String, dynamic> toApiMap() => {'role': role, 'content': content};

  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
        'model': model,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static ChatMessage? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final role = raw['role'];
    final content = raw['content'];
    if (role is! String || content is! String) return null;
    final model = raw['model'];
    final createdAt = raw['createdAt'];
    return ChatMessage(
      role: role,
      content: content,
      model: model is String ? model : null,
      createdAt: createdAt is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : DateTime.now(),
    );
  }
}

/// AI 调用的失败原因。区分「配置问题」与「服务端问题」，因为前者要改设置，
/// 后者只需要重试。
enum AiFailure {
  /// 没配端点或端点被禁用。
  notConfigured,

  /// 地址或密钥无效。
  unauthorized,

  /// 额度用尽或触发限流。
  rateLimited,

  /// 服务端返回了错误。
  serverError,

  /// 响应格式不认识。
  badResponse,

  /// 网络不通。
  network,

  /// 请求被取消。
  cancelled,
}

class AiException implements Exception {
  const AiException(this.failure, this.message);

  final AiFailure failure;
  final String message;

  /// 给用户看的一句话。不含地址与密钥。
  String get userMessage => switch (failure) {
        AiFailure.notConfigured => '还没配置 AI 服务，请到设置里添加',
        AiFailure.unauthorized => '密钥无效或已失效，请检查后重试',
        AiFailure.rateLimited => '额度不足或请求太频繁，请稍后再试',
        AiFailure.serverError => message,
        AiFailure.badResponse => '返回的内容无法解析，请换一个模型试试',
        AiFailure.network => '网络连接失败，请检查网络后重试',
        AiFailure.cancelled => '已取消',
      };

  @override
  String toString() => 'AiException($failure): $message';
}

/// OpenAI 兼容的对话客户端。
///
/// 只依赖 [HttpTransport]，所以测试可以用假传输层跑完整流程，不需要起真服务。
class AiClient {
  AiClient({HttpTransport? transport})
      : _transport = transport ?? const IoHttpTransport();

  final HttpTransport _transport;

  static const _path = '/chat/completions';

  /// 默认的系统提示。要求用原文语言回答，因为中英混排的书不能丢原文。
  static const systemPrompt = '你是阅读助手。用书籍原文的语言回答，'
      '引用原文时保留原句。不知道就说不知道，不要编造书中没有的情节。';

  /// 发一轮对话，返回助手回复的文本。
  ///
  /// [system] 覆盖默认系统提示。[maxHistory] 限制带上文多少条，
  /// 超出的从最早开始丢。
  Future<String> chat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    String? system,
    int maxHistory = 12,
    double temperature = 0.3,
  }) async {
    if (baseUrl.isEmpty) {
      throw const AiException(AiFailure.notConfigured, '端点地址为空');
    }
    if (model.isEmpty) {
      throw const AiException(AiFailure.notConfigured, '未填写模型名');
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system ?? systemPrompt},
      ..._recent(history, maxHistory).map((m) => m.toApiMap()),
    ];

    final url = Uri.parse('$baseUrl$_path');
    final response = await _post(url, {
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'stream': false,
    }, apiKey);

    return _readContent(response);
  }

  Future<TransportResponse> _post(
    Uri url,
    Map<String, dynamic> body,
    String apiKey,
  ) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
    };
    try {
      return await _transport.post(url, headers: headers, body: body);
    } on TransportException catch (e) {
      throw AiException(AiFailure.network, e.message);
    }
  }

  /// 只带最近 [limit] 条。不用 IterableExtension 是为了少一个 import。
  static List<ChatMessage> _recent(List<ChatMessage> history, int limit) {
    if (history.length <= limit) return history;
    return history.sublist(history.length - limit);
  }

  String _readContent(TransportResponse response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiException(AiFailure.unauthorized, '密钥无效');
    }
    if (response.statusCode == 402) {
      throw const AiException(AiFailure.rateLimited, '额度不足');
    }
    if (response.statusCode == 429) {
      throw const AiException(AiFailure.rateLimited, '请求太频繁');
    }
    if (!response.isSuccess) {
      final detail = _errorDetail(response) ?? '服务端返回 ${response.statusCode}';
      throw AiException(AiFailure.serverError, detail);
    }

    final json = response.json;
    if (json == null) {
      throw const AiException(AiFailure.badResponse, '响应不是 JSON');
    }
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiException(AiFailure.badResponse, '响应没有 choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const AiException(AiFailure.badResponse, 'choices 格式不对');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const AiException(AiFailure.badResponse, '没有 message');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiException(AiFailure.badResponse, '回复内容为空');
    }
    return content.trim();
  }

  /// 从错误响应里取出服务端给的一句话。失败时返回 null。
  String? _errorDetail(TransportResponse response) {
    final json = response.json;
    if (json == null) return null;
    final error = json['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    return null;
  }
}

/// 预置的提问模板。对应 Reeden 的提示词，措辞重写。
class AiPrompts {
  const AiPrompts._();

  static const summarizeChapter = '请深度分析本章内容，使用原文语言以一段'
      '精简的话总结，分别涵盖情节发展、人物变化、主题意义，以及可能包含的'
      '伏笔（如果存在）几个方面。需引用原文作为依据，以一个资深读书人的'
      '语气表述，并注意与整部作品的联系。';

  static const pickHighlights = '下面是本章正文。挑出真正值得回看、能概括'
      '情节、人物、观点或伏笔的原文句子，写上简短、有提炼感的备注。不要标'
      '得太碎，也不要勉强标注；如果合适的内容不多，可以少标几条。';

  static const analyzeCharacter = '请深度分析该人物在本书中的人物关系、性格'
      '特点、成长变化和他的最终结局，使用原文语言回答。';

  static const explainBackground = '请介绍与本书相关的背景知识，使用原文'
      '语言回答。';

  static const recommend = '请根据我最近的阅读记录，推荐几本类似的书，'
      '并说明理由。';
}
