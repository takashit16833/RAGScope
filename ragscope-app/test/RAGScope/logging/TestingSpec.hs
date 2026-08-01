module RAGScope.Logging.TestingSpec (
  spec,
) where

import Test.Hspec

spec :: Spec
spec = do
  describe "emit" $ do
    context "minimumLevel未満の場合" $ do
      it "Writerを呼ばず成功する" $ do
        pendingWith "未実装"
