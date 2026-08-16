-- | RAGScopeアプリケーションの構造化ログ基盤で使用する純粋なデータ型を定義する
module RAGScope.Logging.Core (
  -- * 共通Envelope
  SchemaVersion (..),
  ExecutionId (..),
  EventId (..),
  Timestamp (..),
  Component (..),
  EventContext (..),

  -- * イベントの意味
  LogLevel (..),
  OperationName (..),
  EventName (..),

  -- * Payload
  FieldName (..),
  LogValue (..),
  Payload (..),
  emptyPayload,
  payloadFromList,

  -- * Error
  LogErrorCategory (..),
  ErrorCode (..),
  SafeMessage (..),
  LogError (category, code, message, context),
  logError,

  -- * EventSpec
  EventSpec (operation, event, level, payload, errorInfo),
  debugEventSpec,
  infoEventSpec,
  warnEventSpec,
  failedEventSpec,

  -- * 完成済みイベント
  LogEvent (LogEvent, schemaVersion, eventId, timestamp, component, context, spec),
  ToEventSpec (..),
) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Scientific (Scientific)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID.Types (UUID)
import GHC.Generics (Generic)

----------------------------------------------------------
-- 共通Envelope
----------------------------------------------------------

-- | 構造化ログ契約のバージョン
data SchemaVersion
  = SchemaV1
  deriving (Eq, Show)

-- | 1回のCLIコマンドを識別するUUID
newtype ExecutionId
  = ExecutionId UUID
  deriving (Eq, Show)

-- | ログイベント1件を識別するUUID
newtype EventId
  = EventId UUID
  deriving (Eq, Show)

-- | ログイベントが発生したUTC時刻
newtype Timestamp
  = Timestamp UTCTime
  deriving (Eq, Ord, Show)

-- | ログイベントを生成したコンポーネント
data Component
  = -- | RAGScopeアプリケーション
    RAGScopeApp
  | -- | AI推論サービス
    AIService
  deriving (Eq, Show)

-- | ログイベントが属する実行上の文脈
data EventContext
  = -- | 1回のCLIコマンドに属するログイベント
    ExecutionContext ExecutionId
  | -- | サービスの起動・終了などの状態変化
    ServiceContext
  deriving (Eq, Show)

----------------------------------------------------------
-- イベントの意味
----------------------------------------------------------

-- | JSONへ出力する最終的なログレベル
data LogLevel
  = -- | 開発・調査時だけ必要な詳しい情報
    Debug
  | -- | 通常の処理進行と結果
    Info
  | -- | 処理は続けられるが注意が必要
    Warn
  | -- | 処理種別が失敗した
    Error
  deriving (Eq, Ord, Show, Generic)

-- | 追跡する意味のある処理種別
newtype OperationName
  = OperationName Text
  deriving (Eq, Show)

-- | 1つのoperationについて観測した出来事
newtype EventName
  = EventName Text
  deriving (Eq, Show)

----------------------------------------------------------
-- Payload
----------------------------------------------------------

-- | Payloadまたはerror contextの項目名。
newtype FieldName
  = FieldName Text
  deriving (Eq, Ord, Show)

-- | 構造化ログへ記録可能な、@null@を含まないJSON値
data LogValue
  = -- | JSONの文字列値
    LogText Text
  | -- | JSONの数値
    LogNumber Scientific
  | -- | JSONの真偽値
    LogBool Bool
  | -- | JSONの配列
    LogArray [LogValue]
  | -- | JSONのオブジェクト
    LogObject Payload
  deriving (Eq, Show, Generic)

-- | イベント固有情報またはエラー固有の安全な補助情報
newtype Payload
  = Payload (Map FieldName LogValue)
  deriving (Eq, Show, Generic)

-- | 情報を持たない空のPayload
emptyPayload :: Payload
emptyPayload =
  Payload Map.empty

-- | 許可済みの項目からPayloadを構築する
payloadFromList :: [(FieldName, LogValue)] -> Payload
payloadFromList =
  Payload . Map.fromList

----------------------------------------------------------
-- Error
----------------------------------------------------------

-- | 構造化ログへ記録する、失敗の大まかな分類
data LogErrorCategory
  = -- | 入力内容または指定方法に問題がある
    LogInput
  | -- | 必要なファイルなどの資源を利用できない
    LogResource
  | -- | 読み込んだデータが壊れている、または整合しない
    LogData
  | -- | 外部サービス、データベース、モデルなどの依存先が失敗した
    LogDependency
  | -- | 決められた時間内に処理が完了しなかった
    LogTimeout
  | -- | ほかの分類では表せない、RAGScope内部の予期しない失敗
    LogInternal
  deriving (Eq, Show)

-- | 判定や検索に使用する安定したエラーコード。
newtype ErrorCode
  = ErrorCode Text
  deriving (Eq, Show)

-- | ログへ公開してよい、安全性を確認済みのメッセージ。
newtype SafeMessage
  = SafeMessage Text
  deriving (Eq, Show)

-- | 構造化ログの @error@ へ記録する、安全なエラー情報
data LogError = LogError
  { category :: LogErrorCategory
  -- ^ 失敗の大まかな分類
  , code :: ErrorCode
  -- ^ 失敗を機械的に識別するための、安定したエラーコード
  , message :: SafeMessage
  -- ^ 利用者やログへ公開してよい、安全な説明
  , context :: Maybe Payload
  -- ^ 調査や判断に必要な、安全性を確認済みの補助情報
  }
  deriving (Eq, Show)

-- | 必須項目をそろえた安全なログエラーを構築する。
logError ::
  LogErrorCategory ->
  ErrorCode ->
  SafeMessage ->
  Maybe Payload ->
  LogError
logError category code message context =
  LogError
    { category
    , code
    , message
    , context
    }

----------------------------------------------------------
-- EventSpec
----------------------------------------------------------

-- | 機能側で意味が確定したログイベント
data EventSpec = EventSpec
  { operation :: OperationName
  -- ^ 処理種別
  , event :: EventName
  -- ^ 処理について起きた出来事
  , level :: LogLevel
  -- ^ ログレベル
  , payload :: Payload
  -- ^ イベント固有情報
  , errorInfo :: Maybe LogError
  -- ^ 失敗時に記録する安全なエラー情報
  }
  deriving (Eq, Show, Generic)

-- | debug levelの通常イベントを構築する
debugEventSpec :: OperationName -> EventName -> Payload -> EventSpec
debugEventSpec = leveledEventSpec Debug

-- | info levelの通常イベントを構築する
infoEventSpec :: OperationName -> EventName -> Payload -> EventSpec
infoEventSpec = leveledEventSpec Info

-- | warn levelの通常イベントを構築する
warnEventSpec :: OperationName -> EventName -> Payload -> EventSpec
warnEventSpec = leveledEventSpec Warn

leveledEventSpec :: LogLevel -> OperationName -> EventName -> Payload -> EventSpec
leveledEventSpec level operation event payload =
  EventSpec
    { operation
    , event
    , level
    , payload
    , errorInfo = Nothing
    }

-- | 失敗イベントを構築する
--
-- eventをfailed、levelをerrorへ固定し、LogErrorを必須にする
failedEventSpec :: OperationName -> Payload -> LogError -> EventSpec
failedEventSpec operation payload logErrorValue =
  EventSpec
    { operation
    , event = EventName "failed"
    , level = Error
    , payload
    , errorInfo = Just logErrorValue
    }

----------------------------------------------------------
-- 完成済みイベント
----------------------------------------------------------

-- | Runtimeによって共通情報を付加された完成済みログイベント
data LogEvent = LogEvent
  { schemaVersion :: SchemaVersion
  -- ^ ログ契約のバージョン
  , eventId :: EventId
  -- ^ ログイベントの識別子
  , timestamp :: Timestamp
  -- ^ ログイベントを記録した時刻
  , component :: Component
  -- ^ ログイベントの生成元
  , context :: EventContext
  -- ^ 実行またはサービスとの関連情報
  , spec :: EventSpec
  -- ^ 機能側で意味が確定したイベント
  }
  deriving (Eq, Show, Generic)

-- | 機能固有の閉じたイベント型を、共通のEventSpecへ変換する
class ToEventSpec eventType where
  toEventSpec :: eventType -> EventSpec
