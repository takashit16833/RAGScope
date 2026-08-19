from ragscope_ai_service.error.boundary import (
    run_with_unexpected_exception_boundary,
)
from ragscope_ai_service.error.types import AppError, ErrorCategory
from ragscope_ai_service.result import AppResult, Failure, Success


def test_正常結果をそのまま返す() -> None:
    expected = Success(value=42)

    def operation() -> AppResult[int]:
        return expected

    result = run_with_unexpected_exception_boundary(operation)

    assert result is expected


def test_機能側で確定した失敗をそのまま返す() -> None:
    expected = Failure(
        error=AppError(
            category=ErrorCategory.INTERNAL,
            code="document.processing_failed",
            message="The document processing failed",
        )
    )

    def operation() -> AppResult[int]:
        return expected

    result = run_with_unexpected_exception_boundary(operation)

    assert result is expected


def test_想定外例外を安全なinternalエラーへ変換する() -> None:
    cause = RuntimeError("private technical detail")

    def operation() -> AppResult[int]:
        raise cause

    result = run_with_unexpected_exception_boundary(operation)

    assert isinstance(result, Failure)
    assert result.error.category is ErrorCategory.INTERNAL
    assert result.error.code == "internal.unexpected"
    assert result.error.message == "An unexpected internal error occurred."
    assert result.error.cause is cause
    assert "private technical detail" not in result.error.message
