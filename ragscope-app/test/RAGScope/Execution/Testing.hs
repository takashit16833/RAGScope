-- Execution境界のテストで共有するfixtureを定義する
module RAGScope.Execution.Testing (
  TestCause (..),
  fixedAppError,
) where

import Control.Exception (Exception (toException))
import Data.Map.Strict qualified as Map

import RAGScope.Error.Types (
  AppError (..),
  ErrorCategory (Input),
  ErrorCode (ErrorCode),
  ErrorContext (ErrorContext),
  ErrorMessage (ErrorMessage),
  ErrorValue (ErrorText),
  FieldName (FieldName),
 )

-- SomeExceptionの中に元の例外値が保持されることを検査するためのテスト用例外。
data TestCause = TestCause
  deriving (Eq, Show)

instance Exception TestCause

-- Execution境界のテストで共通利用する固定AppError。
fixedAppError :: AppError
fixedAppError =
  AppError
    { category = Input
    , code = ErrorCode "error"
    , message = ErrorMessage "error"
    , context =
        Just
          ( ErrorContext
              (Map.fromList [(FieldName "hoge", ErrorText "fuga")])
          )
    , cause = Just (toException TestCause)
    }
