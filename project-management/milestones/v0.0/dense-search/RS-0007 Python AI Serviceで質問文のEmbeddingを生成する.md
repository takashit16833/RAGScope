---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0007 Python AI Serviceで質問文のEmbeddingを生成する

## 目的

v0.0で文書チャンクを質問との意味的な近さによって検索するためには、利用者が入力した質問文を、保存済みの文書チャンクEmbeddingと比較できる質問Embeddingへ変換する必要がある。

このTicketでは、RS-0013で設計・更新した質問Embeddingの契約に従い、Python AI Serviceへ質問Embedding生成機能を実装する。RS-0003で採用したものと同じEmbedding model、revision、Tokenizerおよび固定生成条件を使用し、文書用と質問用で異なる入力規則がある場合は、Python AI Service内で質問用の規則を適用する。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- `docs/design/Embedding生成設計.md`とOpenAPIに、質問Embeddingの入力規則とAPI契約が反映されている
- `RS-0003`が完了し、文書Embedding生成に使用するmodelと固定生成条件が実装されている

## 完了条件

- [ ] RS-0003で採用したものと同じEmbedding model、revision、Tokenizerを利用して質問Embeddingを生成できる
- [ ] 設計で固定した質問用の入力規則、pooling、最大入力長、truncation、vector正規化が適用される
- [ ] Python AI Serviceが、1件の空でない質問文を受け取り、その質問文に対応するEmbeddingを返せる
- [ ] 文書用と質問用のEmbedding生成をAPI契約上で区別し、質問文へ文書用のprefixまたはinstructionを誤って適用しない
- [ ] 生成される質問Embeddingが、保存済みの文書チャンクEmbeddingと同じvector次元を持つ
- [ ] 生成される質問Embeddingに、`NaN`や無限大など利用できない値が含まれないことを確認できる
- [ ] 使用中のmodel ID、revision、Embeddingの出力次元を既存の確認方法から取得できる
- [ ] 空文字または空白だけの質問文、不正なrequestを、正常なEmbedding生成と区別できるエラーとして扱える
- [ ] モデルをロードできない場合と質問Embeddingの生成に失敗した場合を、正常終了と区別して確認できる
- [ ] requestの検証、質問用入力規則の適用、vector次元、有限値、主要な異常系を自動テストで確認できる
- [ ] 採用した実モデルを使用し、質問文から文書チャンクEmbeddingと比較可能なEmbeddingを生成できることを統合テストまたは実行によって確認できる
- [ ] 実装された質問Embedding APIとOpenAPIのrequest / response、必須条件、エラー形式が一致している
- [ ] 実装で具体化または変更された質問Embedding生成の現在設計が`docs/design/Embedding生成設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計に解消していない差異がない
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
- Embedding modelや生成条件を切り替える設定管理・version管理
- Embedding cache
- 大規模batch処理、非同期job、分散推論
- GPUやAWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「7. 質問と実験の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問と実験の全体フロー>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [検索設計](<../../../../docs/design/検索設計.md>)

## 実装メモ

- Python AI ServiceはAI推論だけを担当し、質問の永続化、dense検索、RAGScope全体の処理順序を管理しない。
- 質問Embedding生成には、設計とOpenAPIで定めた既存APIの拡張または再利用方法を使用する。
- 文書用と質問用でprefixやinstructionが異なるモデルでは、呼び出し側が加工済み文字列を組み立てるのではなく、Python AI Serviceが用途に応じた固定規則を適用する。
- 質問文そのものに不要な正規化や改変を行わない。ただし、空文字または空白だけの入力を無効として検証するための判定は行ってよい。
- RS-0003でロード済みのモデルを再利用し、質問処理のたびにモデルを再ロードしない。
- 自動テストではEmbeddingの浮動小数点値そのものの完全一致へ過度に依存せず、入力用途、次元、有限値、エラー分類などの契約を主に確認する。
- 初期設計またはOpenAPIを変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装した質問Embedding生成処理とAPI
> - 適用した質問用入力規則
> - 実行したテストコマンドと結果
> - 実モデルを使用した質問Embedding生成の確認結果
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
