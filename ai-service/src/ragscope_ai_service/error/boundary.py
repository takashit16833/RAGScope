from collections.abc import Callable

from ..result import AppResult, Failure
from .types import AppError, ErrorCategory


def run_with_unexpected_exception_boundary[T](
    operation: Callable[[], AppResult[T]],
) -> AppResult[T]:
    """想定外の例外を安全な共通エラーへ変換する境界。"""

    try:
        return operation()
    except Exception as cause:  # noqa: BLE001
        # 想定外例外を共通エラーへ閉じ込める最外側の境界なので、ここだけ広く捕捉する。
        return Failure(
            error=AppError(
                category=ErrorCategory.INTERNAL,
                code="internal.unexpected",
                message="An unexpected internal error occurred.",
                cause=cause,
            )
        )
