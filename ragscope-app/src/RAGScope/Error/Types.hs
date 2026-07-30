module RAGScope.Error.Types where

-- | エラー分類
--
-- 失敗の大まかな種類
data ErrorCategory
  = -- | 入力内容または指定方法に問題がある
    Input
  | -- | 必要なファイルなどの資源を利用できない
    Resource
  | -- | 読み込んだデータが壊れている、または整合しない
    Data
  | -- | 外部サービス、データベース、モデルなどの依存先が失敗した
    Dependency
  | -- | 決められた時間内に処理が完了しなかった
    Timeout
  | -- | ほかの分類では表せない、RAGScope内部の予期しない失敗
    Internal
  deriving (Eq, Ord, Show)
