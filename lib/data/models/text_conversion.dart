/// Script conversion preferences shared by the reader and the settings layer.
library;

/// Which script the reader should render.
enum ChineseConversion { none, toSimplified, toTraditional }

extension ChineseConversionX on ChineseConversion {
  String get label => switch (this) {
        ChineseConversion.none => '不转换',
        ChineseConversion.toSimplified => '转简体',
        ChineseConversion.toTraditional => '转繁体',
      };
}

/// Regional glyph standard applied when converting to Traditional Chinese.
enum TraditionalVariant { standard, taiwan, hongKong }

extension TraditionalVariantX on TraditionalVariant {
  String get label => switch (this) {
        TraditionalVariant.standard => '通用繁体',
        TraditionalVariant.taiwan => '台湾正体',
        TraditionalVariant.hongKong => '香港繁体',
      };
}
