#!/usr/bin/env python3
"""Regenerate the Simplified/Traditional conversion assets.

Sources
-------
* OpenCC dictionaries (Apache-2.0), which are curated for conversion and list
  context-ordered candidates for ambiguous characters:
  ``STCharacters`` / ``TSCharacters`` (single characters),
  ``STPhrases`` / ``TSPhrases`` (phrases),
  ``TWVariants`` / ``HKVariants`` (regional glyph standards).
  https://github.com/BYVoid/OpenCC
* Unicode Unihan ``Unihan_Variants.txt`` as a supplement for characters OpenCC
  does not cover (``kSimplifiedVariant`` / ``kTraditionalVariant``).
  https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip

Only the first candidate of each entry is used, and every mapping is required to
keep the same UTF-16 length so the reader's highlight and bookmark offsets stay
valid when the script is switched.

Outputs ``assets/convert/*.txt`` as ``key<TAB>value`` pairs, which
``lib/features/reader/convert/chinese_convert.dart`` loads at runtime.

Usage
-----
    python scripts/generate_convert_tables.py --workdir <dir with sources>

The workdir must contain ``Unihan.zip`` and the OpenCC ``*.txt`` dictionaries.
"""

from __future__ import annotations

import argparse
import os
import zipfile

OPENCC_BASE = "https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary"

OPENCC_FILES = {
    "s2t_chars.txt": "STCharacters.txt",
    "t2s_chars.txt": "TSCharacters.txt",
    "s2t_phrases.txt": "STPhrases.txt",
    "t2s_phrases.txt": "TSPhrases.txt",
    "tw_chars.txt": "TWVariants.txt",
    "hk_chars.txt": "HKVariants.txt",
}


def utf16_len(text: str) -> int:
    """Length in UTF-16 code units, which is what Dart string offsets count.

    A few Unihan mappings swap a BMP character for one outside the BMP (or the
    other way round). Those change the offset arithmetic the reader relies on,
    so they are dropped.
    """
    return len(text.encode("utf-16-le")) // 2


def keep(key: str, value: str) -> bool:
    return bool(key) and bool(value) and key != value and utf16_len(key) == utf16_len(value)


def load_opencc(path: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            key = parts[0].strip()
            value = parts[1].split()[0].strip()
            if keep(key, value):
                pairs.append((key, value))
    return pairs


def load_unihan(workdir: str) -> tuple[list, list]:
    s2t: list[tuple[str, str]] = []
    t2s: list[tuple[str, str]] = []
    with zipfile.ZipFile(os.path.join(workdir, "Unihan.zip")) as archive:
        raw = archive.read("Unihan_Variants.txt").decode("utf-8")

    for line in raw.splitlines():
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        codepoint, field, value = parts[0], parts[1], parts[2]
        variants = [v for v in value.split() if v.startswith("U+")]
        if not variants:
            continue
        try:
            char = chr(int(codepoint[2:], 16))
            first = chr(int(variants[0][2:], 16))
        except ValueError:
            continue
        if not keep(char, first):
            continue
        if field == "kTraditionalVariant":
            s2t.append((char, first))
        elif field == "kSimplifiedVariant":
            t2s.append((char, first))

    return sorted(s2t), sorted(t2s)


def write_pairs(path: str, pairs: list[tuple[str, str]]) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        for key, value in pairs:
            handle.write(f"{key}\t{value}\n")
    print(f"{os.path.basename(path)}: {len(pairs)} entries, {os.path.getsize(path)} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workdir", default=".", help="directory holding the sources")
    parser.add_argument(
        "--out",
        default=os.path.join("assets", "convert"),
        help="output directory for the generated assets",
    )
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)

    unihan_s2t, unihan_t2s = load_unihan(args.workdir)

    for target, source in OPENCC_FILES.items():
        source_path = os.path.join(args.workdir, source)
        if not os.path.exists(source_path):
            raise SystemExit(
                f"missing {source_path}; download it from {OPENCC_BASE}/{source}"
            )
        pairs = sorted(set(load_opencc(source_path)))

        # Supplement the single character tables with anything OpenCC omits.
        if target == "s2t_chars.txt":
            known = {key for key, _ in pairs}
            pairs = sorted(set(pairs) | {p for p in unihan_s2t if p[0] not in known})
        elif target == "t2s_chars.txt":
            known = {key for key, _ in pairs}
            pairs = sorted(set(pairs) | {p for p in unihan_t2s if p[0] not in known})

        write_pairs(os.path.join(args.out, target), pairs)


if __name__ == "__main__":
    main()
