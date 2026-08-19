from dataclasses import dataclass

from .error.types import AppError


@dataclass(frozen=True)
class Success[T]:
    """正常終了した値。"""

    value: T


@dataclass(frozen=True)
class Failure:
    """共通エラーとして確定した失敗。"""

    error: AppError


type AppResult[T] = Success[T] | Failure
