---
note_type: adr
status: accepted
---
# ADR-0008 — RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする

## 背景

`ragscope-app/`は1つのCabal package `ragscope`として構成されており、現在は無名のmain libraryが1つ存在する。今後、文書、検索・回答生成、評価データ、実験・評価などの機能実装が増える。

Cabalの`build-depends`はcomponent単位で依存を宣言する。同じlibraryに複数機能を集約すると、そのlibraryへ追加したpackage依存を、同じcomponent内のすべてのmoduleが利用できる。機能ごとに必要な依存が異なっても、main libraryだけではCabalによる静的な依存制約として表現できない。

RAGScopeでは、関数、module、componentが担当する責務に必要な依存だけを持つことを規約としている。また、Haskellコードでは純粋な型やドメイン処理からHTTP、DBなどの具体的な境界実装へ依存しない方向を守る必要がある。

このため、main libraryを将来の全機能実装の置き場として成長させるのではなく、機能実装と依存をCabal componentとして分離する構成を決める必要がある。

## 決定

1. `ragscope-app/`は1つのCabal package `ragscope`として維持する。
2. 無名のmain library `ragscope`は、RAGScopeアプリケーションの公開APIをまとめる薄いFacadeとする。機能実装の包括的な置き場として使用しない。
3. 文書、検索・回答生成、評価データ、実験・評価の機能実装は、`document`、`retrieval`、`evaluation-data`、`experiment-evaluation`のprivate named libraryへ分ける。各libraryは、その機能を実装する時点で追加し、空libraryを先行して作らない。
4. main libraryからfeature libraryへ依存し、feature libraryからmain libraryへは依存しない。
5. feature library同士の依存は、実際に利用する型、module、関数/APIがある場合だけ`build-depends`へ明示する。同じpackage内に存在することだけを理由に依存を追加しない。
6. feature libraryの一部だけがHTTP、DB、SDKなどの具体的な外部packageを必要とし、その依存を他のmoduleへ許可したくない場合は、境界またはAdapterを担当する別private libraryへ分ける。
7. 正確なcomponent名、`build-depends`、公開module、型、関数は`ragscope.cabal`とHaskellコード・テストを機械可読な正本とする。

## 検討した選択肢

### 全機能をmain libraryへ入れる

既存のCabal構成をそのまま利用できる。一方、文書、検索、評価、実験など異なる機能が同じcomponentの`build-depends`を共有するため、ある機能だけが必要な外部packageやRAGScope内libraryを他の機能からも利用できる。

機能が増えるほど、どの依存がどの責務に必要なのかをCabalから判断できなくなり、RAGScopeの「担当する責務に必要な依存だけを持つ」という規約を静的な構成として表現できないため採用しない。

### main libraryへ機能実装を残し、外部Adapterだけprivate libraryへ出す

OpenTelemetry SDK、DB、HTTP clientなど特定の外部依存だけを隔離することはできる。一方、文書、検索・回答生成、評価データ、実験・評価の機能実装自体は同じmain libraryへ残るため、機能間の不要な静的依存をCabalでは制約できない。

外部packageへの依存だけでなく、RAGScope内の機能責務と依存関係も明示するという今回の目的を満たさないため採用しない。

### 機能ごとに別Cabal packageへ分ける

package単位でも依存を制約できる。しかし、現在のRAGScopeアプリケーションは1つの配布・ビルド対象として管理でき、機能ごとに独立したpackageとしてversionや配布単位を持たせる要求はない。

依存境界は同一package内のprivate named libraryで表現できるため、package分割までは行わない。

### 1 packageのままmain libraryをFacadeとし、機能実装をprivate libraryへ分ける

RAGScopeアプリケーションを1 packageとして維持したまま、機能責務ごとに`build-depends`を分離できる。main libraryを公開Facadeとして保つことで、利用側へprivate libraryの内部構成を直接公開せず、機能実装側には必要な依存だけを許可できる。

この構成を採用する。

## 結果と影響

- main libraryへ機能実装と機能固有の依存を追加しない。
- 各feature libraryの依存関係が`ragscope.cabal`の`build-depends`として見えるようになる。
- feature libraryはprivateであるため、RAGScopeアプリケーションとして公開するAPIはmain library側で整理できる。
- 新しい機能を追加するときはmain libraryへ直接実装を追加せず、その機能を担当するprivate libraryを設ける。
- 1つのfeature library内でも、具体的な外部依存を一部moduleだけへ限定する必要が生じた場合は、さらにprivate libraryを分ける。
- 機能間の具体的な依存方向は、存在しない将来の呼び出しを先取りせず、実装時の型、module、関数/APIと`build-depends`で確定する。

## 関連文書

- [RAGScopeドメインモデル](../design/RAGScopeドメインモデル.md)
- [システムアーキテクチャ](../design/システムアーキテクチャ.md)
- [Haskellコーディング規約](../rules/Haskellコーディング規約.md)
