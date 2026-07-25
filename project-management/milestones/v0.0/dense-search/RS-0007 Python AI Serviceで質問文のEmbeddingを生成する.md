---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0007 Python AI Serviceで質問文のEmbeddingを生成する

## 目的

v0.0で文書チャンクを質問との意味的な近さによって検索するためには、利用者が入力した質問文を、保存済みの文書チャンクEmbeddingと比較できる質問Embeddingへ変換する必要がある。

このTicketでは、RS-0003で採用したものと同じEmbedding model、revision、Tokenizerおよび固定した生成条件を利用し、Python AI Serviceが1件の質問文からEmbeddingを生成できるようにする。文書用と質問用で異なるprefixやinstructionが必要な場合は、RS-0003で定めた質問用の入力規則をPython AI Service内で適用する。

生成した質問Embeddingは、文書チャンクEmbeddingと同じvector次元と互換性を持ち、後続のHaskell側API clientから取得できるAPI応答として返す。

## 完了条件

- [ ] RS-0003で採用したものと同じEmbedding model、revision、Tokenizerを利用して質問Embeddingを生成できる
- [ ] RS-0003で固定した質問用の入力規則、pooling、最大入力長、truncation、vector正規化の有無が適用される
- [ ] Python AI Serviceが、1件の空でない質問文を受け取り、その質問文に対応するEmbeddingを返せる
- [ ] 文書用と質問用のEmbedding生成をAPI契約上で区別し、質問文へ文書用のprefixまたはinstructionを誤って適用しない
- [ ] 生成される質問Embeddingが、保存済みの文書チャンクEmbeddingと同じvector次元を持つ
- [ ] 生成される質問Embeddingに、`NaN`や無限大など数値として利用できない値が含まれないことを確認できる
- [ ] 使用中のmodel ID、revision、Embeddingの出力次元を、APIの応答またはモデル情報を返す既存処理から確認できる
- [ ] 空文字または空白だけの質問文、不正なrequestを、正常なEmbedding生成と区別できるエラーとして扱える
- [ ] モデルをロードできない場合と質問Embeddingの生成に失敗した場合を、正常終了と区別して確認できる
- [ ] requestの検証、質問用入力規則の適用、vector次元、有限値、主要な異常系を自動テストで確認できる
- [ ] 採用した実モデルを使用し、質問文から文書チャンクEmbeddingと比較可能なEmbeddingを生成できることを統合テストまたは実行によって確認できる
- [ ] 質問Embedding生成を含む正確なrequest / responseを、RS-0003で作成したOpenAPIなどの機械可読な定義へ反映できる
- [ ] 文書用・質問用Embeddingの入力規則と互換性を保つ条件を`docs/design/Embedding生成設計.md`へ反映できる
- [ ] プロジェクトで定めたPython側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- Embedding model、revision、Tokenizerの新たな選定または比較
- 文書チャンクEmbeddingを生成する処理の新規実装
- HaskellからPython AI Serviceを呼び出す処理
- Haskellの質問型とAPI request / response型の変換
- PostgreSQL / pgvectorへの接続
- 質問Embeddingを使用したdense検索
- 検索結果の順位付け、取得、CLI表示
- 質問、質問Embedding、検索結果の永続化
- 全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- Embedding modelや生成条件を切り替える設定管理・バージョン管理
- Embedding cache
- 大規模batch処理、非同期job、分散推論
- GPUやAWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「7. 質問と実験の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問と実験の全体フロー>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)

## 実装メモ

- Python AI ServiceはAI推論だけを担当し、質問の永続化、dense検索、RAGScope全体の処理順序を管理しない。
- 質問Embedding生成には、RS-0003で文書Embedding生成に使用した`POST /embeddings`を拡張または再利用する。正確な用途の指定方法、項目名、型、必須条件、エラー形式はOpenAPIなどの機械可読な定義を正本とする。
- 文書用と質問用でprefixやinstructionが異なるモデルでは、呼び出し側が加工済み文字列を組み立てるのではなく、Python AI Serviceが用途に応じた固定規則を適用する。
- 質問文そのものに対する不要なtrim、正規化、改変は行わない。ただし、空文字または空白だけの入力を無効として検証するための判定は行ってよい。
- RS-0003でロード済みのモデルを再利用し、質問処理のたびにモデルを再ロードしない。
- 自動テストでは、Embeddingの浮動小数点値そのものの完全一致へ過度に依存せず、入力用途、次元、有限値、エラー分類などの契約を主に確認する。
- 実モデルを使用した確認では、質問Embeddingと文書チャンクEmbeddingの意味的な検索品質までは評価せず、同じモデル・条件・次元で比較可能なvectorを生成できることを確認する。

## 結果

> [!note] 完了時に記入
> - 実装した質問Embedding生成処理とAPI
> - 使用したmodel、revision、Tokenizer
> - 適用した質問用の入力規則と出力次元
> - 実行したテストコマンドと結果
> - 実モデルを使用した質問Embedding生成の確認結果
> - 更新したOpenAPI・Embedding生成設計
> - 既知の制約
> - 関連Pull Request
