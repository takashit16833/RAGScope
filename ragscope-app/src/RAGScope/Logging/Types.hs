-- | RAGScopeアプリケーションにおける構造化ログの型を定義する
module RAGScope.Logging.Types (LogLevel (..)) where

-- | 処理への影響の大きさ
data LogLevel
  = -- | 開発・調査時だけ必要な詳しい情報
    Debug
  | -- | 通常の処理進行と結果
    Info
  | -- | 処理は続けられるが注意が必要
    Warn
  | -- | 処理種別が失敗した
    Error
  deriving (Eq, Ord, Show)
