-- | RAGScopeアプリケーションで共通利用するエラー型を定義する
module RAGScope.Error.Types (
  ErrorCategory (..),
  ErrorCode (..),
  ErrorMessage (..),
  FieldName (..),
  ErrorContext (..),
  ErrorValue (..),
  ErrorCause,
  AppError (..),
  AppResult,
) where

import Control.Exception (SomeException)
import Control.Monad.Trans.Except
import Data.Map.Strict (Map)
import Data.Scientific (Scientific)
import Data.Text (Text)

-- | エラー分類
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
  deriving (Eq, Show)

-- | 判定・検索に使用する安定した識別子
newtype ErrorCode = ErrorCode Text deriving (Show)

-- | 利用者へ見せてもよい説明
newtype ErrorMessage = ErrorMessage Text deriving (Show)

-- | 調査や判断に使う安全な情報
newtype FieldName
  = FieldName Text
  deriving (Eq, Show, Ord)

-- | イベント固有情報またはエラー固有の安全な補助情報
newtype ErrorContext
  = ErrorContext (Map FieldName ErrorValue)
  deriving (Eq, Show)

-- | 構造化ログへ記録可能な、@null@を含まないJSON値
data ErrorValue
  = -- | JSONの文字列値
    ErrorText Text
  | -- | JSONの数値
    ErrorNumber Scientific
  | -- | JSONの真偽値
    ErrorBool Bool
  | -- | JSONの配列
    ErrorArray [ErrorValue]
  | -- | JSONのオブジェクト
    ErrorObject ErrorContext
  deriving (Eq, Show)

-- | 元の技術的な例外
type ErrorCause = SomeException

-- | アプリ共通エラー
data AppError = AppError
  { category :: ErrorCategory
  -- ^ エラー分類
  , code :: ErrorCode
  -- ^ 判定・検索に使用する安定した識別子
  , message :: ErrorMessage
  -- ^ 利用者へ見せてもよい説明
  , context :: Maybe ErrorContext
  -- ^ イベント固有情報またはエラー固有の安全な補助情報
  , cause :: Maybe ErrorCause
  -- ^ 元の技術的な例外
  }
  deriving (Show)

-- | アプリの実行結果（正常／失敗）
type AppResult a = ExceptT AppError IO a
