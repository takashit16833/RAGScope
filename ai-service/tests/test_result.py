from ragscope_ai_service.error.types import AppError, ErrorCategory
from ragscope_ai_service.result import Failure, Success


def test_Successが正常結果を保持する() -> None:
    result = Success(value=42)

    assert result.value == 42


def test_Failureが共通エラーを保持する() -> None:
    error = AppError(
        category=ErrorCategory.INTERNAL,
        code="test.failed",
        message="The test operation failed.",
    )

    result = Failure(error=error)

    assert result.error is error
