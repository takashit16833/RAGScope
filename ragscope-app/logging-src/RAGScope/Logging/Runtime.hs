-- | ログイベントへID・時刻・contextを付加し、filter後にWriterへ渡す
module RAGScope.Logging.Runtime (
  Logger,
  LoggingFailure (..),
  EventIdSource,
  Clock,
  Writer,
  mkLogger,
  emit,
) where

import RAGScope.Logging.Core (
  Component,
  EventContext,
  EventId,
  EventSpec (level),
  LogEvent (..),
  LogLevel,
  SchemaVersion (SchemaV1),
  Timestamp,
  ToEventSpec (..),
 )

-- | ログ基盤自身の失敗
--
-- 同じ失敗したログ経路へ再帰的に記録せず、呼び出し元へ返す
data LoggingFailure
  = -- | ログイベントのJSON変換に失敗
    LoggingEncodingFailure
  | -- | 変換済みログの出力に失敗
    LoggingSinkFailure
  deriving (Eq, Show)

-- | ログイベントごとに新しいEventIdを供給する処理
type EventIdSource = IO EventId

-- | 現在時刻をTimestampとして供給する処理
type Clock = IO Timestamp

-- | 完成済みLogEventを最終的な出力先へ渡す処理
type Writer = LogEvent -> IO (Either LoggingFailure ())

-- | Logging Runtimeの依存と設定
data Logger = Logger
  { minimumLevel :: LogLevel
  -- ^ 出力する最低ログレベル
  , component :: Component
  -- ^ ログイベントの生成元
  , context :: EventContext
  -- ^ 実行またはサービスとの関連情報
  , eventIdSource :: EventIdSource
  -- ^ イベントIDの生成元
  , clock :: Clock
  -- ^ 記録時刻の取得元
  , writer :: Writer
  -- ^ 完成したログイベントの出力処理
  }

-- | 依存を注入してLoggerを構築する
mkLogger ::
  LogLevel ->
  Component ->
  EventContext ->
  EventIdSource ->
  Clock ->
  Writer ->
  Logger
mkLogger minimumLevel component context eventIdSource clock writer =
  Logger
    { minimumLevel
    , component
    , context
    , eventIdSource
    , clock
    , writer
    }

-- | 型付き機能イベントを受け付け、設定されたWriterへ出力する
--
-- 最低ログレベル未満なら何も出力せず成功とする
emit ::
  (ToEventSpec eventType) =>
  Logger ->
  eventType ->
  IO (Either LoggingFailure ())
emit logger eventValue =
  let -- 機能固有イベントを共通のEventSpecへ変換する
      eventSpec = toEventSpec eventValue
   in -- 最低ログレベル未満なら何も出力せず成功とする
      if eventSpec.level < logger.minimumLevel
        then pure (Right ())
        else do
          -- 出力するイベントのIDと時刻を取得する
          eventId <- logger.eventIdSource
          timestamp <- logger.clock

          -- Loggerの共通情報を付加してLogEventを完成させる
          let logEvent =
                LogEvent
                  { schemaVersion = SchemaV1
                  , eventId
                  , timestamp
                  , component = logger.component
                  , context = logger.context
                  , spec = eventSpec
                  }

          -- 完成したログイベントをWriterへ渡す
          logger.writer logEvent
