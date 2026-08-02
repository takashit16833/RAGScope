-- | composition rootで構造化ログの実行環境を初期化するFacade。
--
-- 実行ID、context、時計、イベントID生成、出力先の組み合わせをこの境界へ集約し、
-- 通常の機能処理から初期化の詳細を隠す。
module RAGScope.Logging.Setup () where
