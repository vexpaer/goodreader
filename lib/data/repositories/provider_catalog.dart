import '../models/service_endpoint.dart';

/// 预置服务目录。
///
/// 只列「协议已知、地址公开」的服务。模型名会过期，所以一律做成可自由
/// 输入的建议值，不当作可选集合。用户总能选手动输入走完全自定义的端点。
class ProviderCatalog {
  const ProviderCatalog._();

  static const ai = <ProviderPreset>[
    ProviderPreset(
      id: 'openai',
      name: 'OpenAI',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.openai.com/v1',
      models: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
      hint: '官方接口，需要海外网络',
    ),
    ProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.deepseek.com/v1',
      models: ['deepseek-chat', 'deepseek-reasoner'],
      hint: '国内可直连，按量计费',
    ),
    ProviderPreset(
      id: 'qwen',
      name: '通义千问',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: ['qwen-plus', 'qwen-turbo', 'qwen-max'],
      hint: '阿里云百炼，OpenAI 兼容模式',
    ),
    ProviderPreset(
      id: 'zhipu',
      name: '智谱 GLM',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      models: ['glm-4-plus', 'glm-4-air', 'glm-4-flash'],
      hint: 'GLM-4-Flash 长期免费',
    ),
    ProviderPreset(
      id: 'moonshot',
      name: 'Moonshot',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.moonshot.cn/v1',
      models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
      hint: '长上下文，适合整章分析',
    ),
    ProviderPreset(
      id: 'doubao',
      name: '豆包',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      models: [],
      hint: '火山方舟，模型填推理接入点 ID',
    ),
    ProviderPreset(
      id: 'hunyuan',
      name: '腾讯混元',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
      models: ['hunyuan-turbos-latest', 'hunyuan-lite'],
      hint: '混元，有免费额度',
    ),
    ProviderPreset(
      id: 'baichuan',
      name: '百川',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.baichuan-ai.com/v1',
      models: ['Baichuan4', 'Baichuan4-Turbo'],
    ),
    ProviderPreset(
      id: 'stepfun',
      name: '阶跃星辰',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.stepfun.com/v1',
      models: ['step-2-16k', 'step-1-8k'],
    ),
    ProviderPreset(
      id: 'minimax',
      name: 'MiniMax',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.minimax.chat/v1',
      models: ['MiniMax-Text-01', 'abab6.5s-chat'],
    ),
    ProviderPreset(
      id: 'siliconflow',
      name: '硅基流动',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.siliconflow.cn/v1',
      models: ['Qwen/Qwen2.5-7B-Instruct', 'deepseek-ai/DeepSeek-V3'],
      hint: '聚合多家开源模型，注册送额度',
    ),
    ProviderPreset(
      id: 'lingyiwanwu',
      name: '零一万物',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.lingyiwanwu.com/v1',
      models: ['yi-lightning', 'yi-large'],
    ),
    ProviderPreset(
      id: 'longcat',
      name: 'LongCat',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.longcat.chat/openai',
      models: ['LongCat-Flash-Chat'],
    ),
    ProviderPreset(
      id: 'ppio',
      name: 'PPIO 派欧云',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.ppio.com/v1',
      models: [],
    ),
    ProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://openrouter.ai/api/v1',
      models: [],
      hint: '一个密钥用遍各家模型，含 Claude 与 Gemini',
    ),
    ProviderPreset(
      id: 'groq',
      name: 'Groq',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      models: ['llama-3.3-70b-versatile'],
      hint: '推理速度极快，有免费额度',
    ),
    ProviderPreset(
      id: 'cerebras',
      name: 'Cerebras',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.cerebras.ai/v1',
      models: ['llama-3.3-70b'],
      hint: '免费额度，速度极快',
    ),
    ProviderPreset(
      id: 'together',
      name: 'Together AI',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.together.xyz/v1',
      models: [],
    ),
    ProviderPreset(
      id: 'fireworks',
      name: 'Fireworks',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.fireworks.ai/inference/v1',
      models: [],
    ),
    ProviderPreset(
      id: 'mistral',
      name: 'Mistral',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.mistral.ai/v1',
      models: ['mistral-small-latest', 'mistral-large-latest'],
    ),
    ProviderPreset(
      id: 'cohere',
      name: 'Cohere',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.cohere.ai/compatibility/v1',
      models: ['command-r7b-12-2024'],
      hint: 'OpenAI 兼容入口',
    ),
    ProviderPreset(
      id: 'xai',
      name: 'xAI Grok',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.x.ai/v1',
      models: ['grok-3-mini', 'grok-2-latest'],
    ),
    ProviderPreset(
      id: 'perplexity',
      name: 'Perplexity',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://api.perplexity.ai',
      models: ['sonar', 'sonar-pro'],
      hint: '自带联网检索',
    ),
    ProviderPreset(
      id: 'nvidia',
      name: 'NVIDIA NIM',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://integrate.api.nvidia.com/v1',
      models: [],
      hint: '注册送额度',
    ),
    ProviderPreset(
      id: 'huggingface',
      name: 'HuggingFace Router',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'https://router.huggingface.co/v1',
      models: [],
    ),
    ProviderPreset(
      id: 'ollama',
      name: 'Ollama（本机）',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'http://localhost:11434/v1',
      models: ['qwen2.5:7b', 'llama3.1:8b'],
      hint: '完全本地，不花钱也不联网',
      secretLabel: 'API Key（可留空）',
    ),
    ProviderPreset(
      id: 'lmstudio',
      name: 'LM Studio（本机）',
      kind: ServiceKind.ai,
      defaultBaseUrl: 'http://localhost:1234/v1',
      models: [],
      hint: '桌面端跑本地模型',
      secretLabel: 'API Key（可留空）',
    ),
    ProviderPreset(
      id: 'custom-ai',
      name: '自定义 OpenAI 兼容接口',
      kind: ServiceKind.ai,
      defaultBaseUrl: '',
      models: [],
      hint: '任何实现了 /chat/completions 的服务',
    ),
  ];

  static const sync = <ProviderPreset>[
    ProviderPreset(
      id: 'webdav',
      name: 'WebDAV',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: '自建或任何支持 WebDAV 的网盘',
      secretLabel: '密码',
    ),
    ProviderPreset(
      id: 'jianguo',
      name: '坚果云',
      kind: ServiceKind.sync,
      defaultBaseUrl: 'https://dav.jianguoyun.com/dav/',
      models: [],
      hint: '应用密码，不是登录密码',
      secretLabel: '应用密码',
    ),
    ProviderPreset(
      id: 'nextcloud',
      name: 'Nextcloud / ownCloud',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: '填到 remote.php/dav/files/用户名',
      secretLabel: '应用密码',
    ),
    ProviderPreset(
      id: 'alist',
      name: 'AList',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: '自建 AList 的 WebDAV 入口',
      secretLabel: '密码',
    ),
    ProviderPreset(
      id: 's3',
      name: 'Amazon S3',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: '地址填 endpoint，密钥填 Access Key，备注填 Secret',
    ),
    ProviderPreset(
      id: 'r2',
      name: 'Cloudflare R2',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: 'S3 兼容，无出口流量费',
    ),
    ProviderPreset(
      id: 'b2',
      name: 'Backblaze B2',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: 'S3 兼容',
    ),
    ProviderPreset(
      id: 'minio',
      name: 'MinIO（自建）',
      kind: ServiceKind.sync,
      defaultBaseUrl: '',
      models: [],
      hint: '内网对象存储',
    ),
  ];

  static const ocr = <ProviderPreset>[
    ProviderPreset(
      id: 'http-ocr',
      name: '自定义 HTTP 识别服务',
      kind: ServiceKind.ocr,
      defaultBaseUrl: '',
      models: [],
      hint: 'POST 图片，返回识别文本',
    ),
    ProviderPreset(
      id: 'paddleocr',
      name: 'PaddleOCR 服务',
      kind: ServiceKind.ocr,
      defaultBaseUrl: '',
      models: [],
      hint: '自建 PaddleOCR Serving',
    ),
    ProviderPreset(
      id: 'local-ocr',
      name: '端上模型（预留）',
      kind: ServiceKind.ocr,
      defaultBaseUrl: 'local',
      models: [],
      hint: '后续版本接入，当前会提示不可用',
    ),
  ];

  static const tts = <ProviderPreset>[
    ProviderPreset(
      id: 'system-tts',
      name: '系统语音引擎',
      kind: ServiceKind.tts,
      defaultBaseUrl: 'system',
      models: [],
      hint: '用系统自带 TTS，不联网',
      secretLabel: '无需密钥',
    ),
    ProviderPreset(
      id: 'aliyun-tts',
      name: '阿里云语音合成',
      kind: ServiceKind.tts,
      defaultBaseUrl: 'https://nls-gateway.cn-shanghai.aliyuncs.com',
      models: [],
      hint: '需在控制台开通并绑定应用',
    ),
    ProviderPreset(
      id: 'azure-tts',
      name: 'Azure 语音',
      kind: ServiceKind.tts,
      defaultBaseUrl: '',
      models: [],
      hint: '地址填区域端点，如 https://eastus.tts.speech.microsoft.com',
    ),
    ProviderPreset(
      id: 'openai-tts',
      name: 'OpenAI 兼容语音',
      kind: ServiceKind.tts,
      defaultBaseUrl: '',
      models: [],
      hint: '任何实现 /audio/speech 的服务',
    ),
  ];

  static const bookSource = <ProviderPreset>[
    ProviderPreset(
      id: 'custom-source',
      name: '自定义书源',
      kind: ServiceKind.bookSource,
      defaultBaseUrl: '',
      models: [],
      hint: '配置请求地址与解析规则',
    ),
  ];

  static List<ProviderPreset> ofKind(ServiceKind kind) => switch (kind) {
        ServiceKind.ai => ai,
        ServiceKind.sync => sync,
        ServiceKind.ocr => ocr,
        ServiceKind.tts => tts,
        ServiceKind.bookSource => bookSource,
      };

  static List<ProviderPreset> get all => [
        ...ai,
        ...sync,
        ...ocr,
        ...tts,
        ...bookSource,
      ];

  static ProviderPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
