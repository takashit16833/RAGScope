---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0004 Haskellから文書チャンクのEmbeddingを取得する

## 目的

v0.0で文書チャンクとEmbeddingをPostgreSQLへ保存するためには、RS-0002で生成した文書チャンクをHaskellからPython AI Serviceへ渡し、RS-0003で実装したEmbedding生成APIから、各チャンクに対応するEmbeddingを受け取れる必要がある。

このTicketでは、HaskellからHTTP / JSONでPython AI Serviceの文書Embedding生成APIを呼び出す。Haskellが保持する元文書の識別情報、`chunkIndex`、本文と、Python AI Serviceから返されたEmbeddingの対応関係を検証し、後続の保存処理から利用できる値として取得する。

Python AI Serviceの起動やEmbedding生成自体はRS-0003を正本とし、このTicketではHaskell側のAPI client、データ変換、応答検証、エラー処理を実装する。

## 完了条件

- [ ] HaskellからPython AI Serviceの文書Embedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] RS-0002で生成した1件以上の文書チャンクについて、元文書を識別する情報、`chunkIndex`、本文を、Embedding生成APIのrequestへ変換できる
- [ ] Python AI Serviceから成功応答を受け取り、各チャンクに対応するEmbeddingをHaskellの値として取得できる
- [ ] 入力したチャンク件数と返却されたEmbedding件数が一致することを確認できる
- [ ] 入力チャンクとEmbeddingの対応を、API契約で定めた順序または識別子によって一意に検証できる
- [ ] 取得した各Embeddingが、RS-0003で固定したvector次元と一致し、数値として利用できない値を含まないことを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、本文、対応するEmbeddingを保持し、後続の保存処理へ渡せる値を取得できる
- [ ] Python AI Serviceへ接続できない場合を、正常なEmbedding取得と区別して扱える
- [ ] Python AI ServiceがEmbedding生成失敗を返した場合を、正常なEmbedding取得と区別して扱える
- [ ] HTTPの失敗status、不正なJSON、必須項目の欠落を、それぞれ正常な応答と区別して扱える
- [ ] 件数不一致、識別子または順序の不整合、vector次元の不一致を検出し、不正な対応関係を後続処理へ渡さない
- [ ] requestの組み立て、responseのdecode、チャンクとEmbeddingの対応、主要な異常系を自動テストで確認できる
- [ ] 実際に起動したPython AI ServiceをHaskellから呼び出し、複数の文書チャンクに対応するEmbeddingを取得できることを統合テストまたは実行によって確認できる
- [ ] HaskellとPython AI Service間の文書Embedding取得フローと、対応関係を維持する規則を`docs/design/Embedding生成設計.md`へ反映できる
- [ ] プロジェクトで定めたHaskell側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- Python AI Serviceでのモデル選定、モデル・Tokenizerのロード、Embedding生成APIの実装
- Embedding生成APIの正確なrequest / response schemaの新規定義
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンクとEmbeddingのPostgreSQLへの保存
- 保存済みデータの読み出し
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 複数のEmbedding modelまたは生成条件の切り替え・比較
- retry方針、可変timeout、circuit breakerなどの本格的な障害制御
- 大規模batch処理、非同期job、並列リクエスト
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)

## 実装メモ

- HaskellはRAGScopeの処理全体とデータの対応関係を管理し、Python AI ServiceはAI推論だけを担当する。
- APIの正確なpath、request / response、項目名、型、エラー形式は、RS-0003で作成したOpenAPIなどの機械可読な定義を正本として使用する。
- Haskell側では、API用の型とRAGScope内部の文書チャンク型を分け、境界で明示的に変換する。
- Python AI Serviceから返された配列を無条件に入力チャンクへ`zip`せず、API契約で定めた順序または識別子が一致することを検証してから対応付ける。
- 対応付け後の値は、元文書を識別する情報、`chunkIndex`、元の本文、Embeddingを失わずに保持する。正確な型名やフィールド名は実装時に決定する。
- Haskell側でも件数、対応、次元、有限値を検証し、不正なresponseを後続のDB保存へ渡さない。
- 自動テストでは、test serverまたはHTTP clientの差し替えを利用し、実モデルへ毎回依存せずに正常応答と異常応答を確認してよい。
- Python AI Serviceとの実接続確認では、RS-0003で採用した実モデルを使用する。
- v0.0では同期的に1回のrequestで処理し、大規模batch、並列化、retry戦略は導入しない。
- HTTP client library、JSON library、型名などの局所的な選択はコードを正本とし、Ticketへ固定しない。

## 結果

> [!note] 完了時に記入
> - 実装したHaskell側のAPI clientとデータ変換
> - チャンクとEmbeddingの対応方法
> - 実行したテストコマンドと結果
> - Python AI Serviceとの実接続確認結果
> - 確認した主要な異常系
> - 更新した設計文書
> - 既知の制約
> - 関連Pull Request
