---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0008 Haskellから質問文のEmbeddingを取得する

## 目的

v0.0でHaskellがdense検索の処理全体を制御するためには、利用者から受け取った質問文をPython AI Serviceへ渡し、RS-0007で実装した質問Embedding生成APIから検索に使用するEmbeddingを取得できる必要がある。

このTicketでは、RS-0013の初期設計とOpenAPIに従い、HaskellからHTTP / JSONでPython AI Serviceへ1件の質問文を送信し、返された質問EmbeddingをHaskellの値として取得する。応答のvector次元と数値の妥当性を検証し、不正なEmbeddingを後続のPostgreSQL検索へ渡さない。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- [RS-0007 Python AI Serviceで質問文のEmbeddingを生成する](<./RS-0007 Python AI Serviceで質問文のEmbeddingを生成する.md>)が完了している
- `docs/design/Embedding生成設計.md`とOpenAPIが質問Embeddingの実装と一致している

## 完了条件

- [ ] HaskellからPython AI Serviceの質問Embedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] Haskellが保持する1件の空でない質問文を、API requestへ変換できる
- [ ] Python AI Serviceから成功応答を受け取り、質問EmbeddingをHaskellの値として取得できる
- [ ] 取得した質問Embeddingが、設計で定めた文書Embeddingと同じvector次元を持つことを確認できる
- [ ] 取得した質問Embeddingに、`NaN`や無限大など利用できない値が含まれないことを確認できる
- [ ] 元の質問文と対応するEmbeddingを保持し、後続のdense検索処理へ渡せる値を取得できる
- [ ] 空文字または空白だけの質問文をPython AI Serviceへ送信せず、正常なEmbedding取得と区別して扱える
- [ ] Python AI Serviceへ接続できない場合を、正常なEmbedding取得と区別して扱える
- [ ] Python AI Serviceが質問Embedding生成失敗を返した場合を、正常なEmbedding取得と区別して扱える
- [ ] HTTPの失敗status、不正なJSON、必須項目の欠落を、それぞれ正常な応答と区別して扱える
- [ ] vector次元の不一致または有限値でない要素を検出し、不正なEmbeddingを後続処理へ渡さない
- [ ] requestの組み立て、responseのdecode、入力検証、vector検証、主要な異常系を自動テストで確認できる
- [ ] 実際に起動したPython AI ServiceをHaskellから呼び出し、質問文に対応するEmbeddingを取得できることを統合テストまたは実行によって確認できる
- [ ] Haskell側の実装とOpenAPIの契約が一致している
- [ ] 実装で具体化または変更された質問Embedding取得フローが`docs/design/Embedding生成設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計に解消していない差異がない
- [ ] プロジェクトで定めたHaskell側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- Python AI Serviceでのモデル選定、モデル・Tokenizerのロード
- Python AI Serviceで質問Embeddingを生成する処理の実装
- 質問Embedding APIの契約をゼロから設計する作業
- PostgreSQL / pgvectorへの接続
- dense検索query、順位付け、上位チャンクの取得
- Haskell CLIの検索コマンドと質問入力UI
- 検索結果のCLI表示
- 質問、質問Embedding、検索結果の永続化
- 全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 複数のEmbedding modelまたは生成条件の切り替え・比較
- retry方針、可変timeout、circuit breakerなどの本格的な障害制御
- 大規模batch処理、非同期job、並列request
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「7. 質問処理の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問処理の全体フロー>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [検索設計](<../../../../docs/design/検索設計.md>)

## 実装メモ

- HaskellはRAGScopeの処理全体を制御し、Python AI Serviceは質問Embeddingの生成だけを担当する。
- APIの正確なpath、request / response、項目名、型、エラー形式はOpenAPIを正本として使用する。
- RS-0004で実装したHTTP client、共通のAPI型、エラー型、vector検証処理を自然に再利用できる場合は再利用する。
- Haskell側では、API用の型とRAGScope内部で扱う質問・Embeddingの型を分け、境界で明示的に変換する。
- APIから返されたEmbeddingを無条件に受け入れず、後続のpgvector検索へ渡す前に次元と有限値を検証する。
- 自動テストではtest serverまたはHTTP clientの差し替えを利用し、実モデルへ毎回依存せずに正常応答と異常応答を確認してよい。
- v0.0では同期的に1件の質問を処理し、複数質問のbatch、並列化、retry戦略は導入しない。
- 初期設計またはOpenAPIを変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したHaskell側のAPI clientとデータ変換
> - 質問文とEmbeddingの保持方法
> - 実行したテストコマンドと結果
> - Python AI Serviceとの実接続確認結果
> - 確認した主要な異常系
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
