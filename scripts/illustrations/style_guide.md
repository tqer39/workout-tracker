# 水彩イラストスタイルガイド

## 共通テイスト
- 水彩タッチ、パステル基調、人物なし、文字なし
- 紙の質感を残す、柔らかいエッジ
- ほのぼの・温かみのある雰囲気

## prompts.toml の `[style].suffix` で全件に付加する文言

```text
soft watercolor illustration, gentle pastel palette, hand-painted texture,
warm and gentle atmosphere, no text, no people, slight paper grain
```

## 出力スペック
- サイズ: 1024x1024（正方形、SwiftUI で aspectRatio: .fill 表示）
- 形式: PNG
- 透明背景: 不要（風景なので背景色あり）

## 個別プロンプト指針
- **時間帯**（morning/day/evening/night）: 空・地平線中心、光の色味で時間帯を表現
- **チェックポイント** (13箇所): その土地を象徴する自然・建物・名物。観光ポスター風ではなく日常感
