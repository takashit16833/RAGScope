from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum


class ErrorCategory(StrEnum):
    """RAGScope共通エラーの分類。"""

    INPUT = "input"
    RESOURCE = "resource"
    DATA = "data"
    DEPENDENCY = "dependency"
    TIMEOUT = "timeout"
    INTERNAL = "internal"


# エラーcontextへ保持する、安全性を確認済みの構造化値。
type ErrorValue = (
    str | int | float | bool | tuple[ErrorValue, ...] | Mapping[str, ErrorValue]
)


# エラー固有の安全な補助情報。
type ErrorContext = Mapping[str, ErrorValue]


@dataclass(frozen=True)
class AppError:
    """RAGScope共通エラー"""

    category: ErrorCategory
    code: str
    message: str
    context: ErrorContext | None = None

    # 元の技術的な例外は公開情報へ混ざらないようreprから除外する
    cause: Exception | None = field(default=None, repr=False)
