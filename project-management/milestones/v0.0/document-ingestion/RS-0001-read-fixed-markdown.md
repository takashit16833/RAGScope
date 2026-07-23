---
aliases:
  - 固定Markdown文書をHaskellで読み込む
tags:
  - ragscope
note_type: implementation
status: draft
---
# RS-0001 — [Feature] 固定Markdown文書をHaskellで読み込む

> [!summary] このTicketで作る機能
> あらかじめ用意したMarkdownファイルをHaskellでUTF-8テキストとして読み込み、後続のchunk分割処理へ渡せる本文を取得する。
> このTicketでは動作確認のため、取得した本文をターミナルへ表示する。

## 背景

RAGScopeでは、取り込んだMarkdown / TXT文書をHaskellでchunk分割し、その後Python AI ServiceでEmbeddingを生成する。
本Ticketは、その処理の入口として、Markdown文書の本文をHaskellの値として取得できる状態を作る。

## 作成するもの

1. 読み込み確認に使用する小さなMarkdownファイル
2. 指定されたファイルをUTF-8で読み込み、本文を`Text`として返すHaskellの処理
3. 読み込んだ本文をターミナルへ表示し、内容を確認できる実行経路

入力と出力の関係は次のとおり。

```text
固定Markdownファイル
→ HaskellでUTF-8として読み込む
→ 本文をTextとして取得する
→ 動作確認のためターミナルへ表示する
```

> [!example] 実装イメージ
> 関数名やモジュール構成は固定しないが、責務としては次のような処理を想定する。
>
> ```haskell
> readDocument :: FilePath -> IO Text
> ```

## 完了条件

- [ ] 読み込み確認用のMarkdownファイルが1件用意されている
- [ ] HaskellからそのファイルをUTF-8として読み込める
- [ ] 読み込んだ本文を`Text`として取得し、後続処理へ渡せる
- [ ] 実行すると、Markdown記法を含む本文が欠落や文字化けなくターミナルへ表示される
- [ ] 対象ファイルが存在しない場合、原因が分かるエラーとして終了する

## 対象外

- 複数ファイルの一括読み込み
- ファイルやディレクトリの自動探索
- CLI引数や設定ファイルによるパス指定
- LF統一・NFC正規化
- Markdownの解析や記法の削除
- chunk分割
- Embedding生成
- PostgreSQLへの保存

## 参照資料

- [[ragscope-design#4.1 ローカル構成|RAGScope設計書 — Haskellの責務]]
- [[ragscope-design#5.1 文書・評価データ・質問処理の流れ|RAGScope設計書 — 文書取り込み時の処理]]
- [[ragscope-design#12. v0.0 実装内容|RAGScope設計書 — v0.0実装内容]]
- [[v0.0-document-ingestion|v0.0 — 文書取り込みEpic]]

## 作業メモ

着手後に、採用したファイル配置、実行コマンド、実装上の判断を必要な範囲で記録する。

## 結果

完了時に、次を簡潔に記録する。

- 作成した機能の概要
- 動作確認に使用したコマンド
- 確認できた出力またはエラー
- 後続Ticketへ引き継ぐ事項
