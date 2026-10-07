/**
 * AI が返したカード名の候補テキストから、名前だけを取り出す。
 *
 * モデルによっては「# 「Card Rivals」カード名案」のような見出しや前置きを先頭に付けるため、
 * 先頭から3行を機械的に採ると見出しが名前の候補に混ざる（Haiku 4.5 で発生）。
 * 「1. 名前」の番号付き行を優先して採り、番号付きの行が無いときだけ、見出し・箇条書き記号・
 * 空行を除いた行にフォールバックする。
 */
export function parseNameCandidates(text: string, max = 3): string[] {
  const strip = (s: string) =>
    s
      .replace(/\*\*/g, "")
      .replace(/[[\]]/g, "")
      .trim();

  const lines = text.split(/\r?\n/);

  const numbered: string[] = [];
  for (const line of lines) {
    const m = line.match(/^\s*(?:\d+|[①-⑩])\s*[.．)）、]\s*(.+)$/);
    if (m) {
      const name = strip(m[1]);
      if (name.length > 0) numbered.push(name);
    }
  }
  if (numbered.length > 0) return numbered.slice(0, max);

  return lines
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !/^(#|>|[-*•]\s|```)/.test(l))
    .map(strip)
    .filter((l) => l.length > 0)
    .slice(0, max);
}
