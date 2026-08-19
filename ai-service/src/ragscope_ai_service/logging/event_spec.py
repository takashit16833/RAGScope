from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum

from ragscope_ai_service.error.types import AppError, ErrorCategory, ErrorContext

type LogValue = str | int | float | bool | tuple[LogValue, ...] | Mapping[str, LogValue]


type Payload = Mapping[str, LogValue]


class LogLevel(StrEnum):
    """処理への影響の大きさを表すログレベル"""

    DEBUG = "debug"
    INFO = "info"
    WARN = "warn"
    ERROR = "error"


@dataclass(frozen=True)
class LogError:
    """構造化ログへ記録できる安全なエラー情報"""

    category: ErrorCategory
    code: str
    message: str
    context: ErrorContext | None = None


def log_error_from_app_error(error: AppError) -> LogError:
    """AppErrorから構造化ログへ記録可能な情報だけを取り出す"""

    return LogError(
        category=error.category,
        code=error.code,
        message=error.message,
        context=error.context,
    )


@dataclass(frozen=True)
class EventSpec:
    """機能側で意味が確定したログイベント。"""

    operation: str
    event: str
    level: LogLevel
    payload: Payload
    error: LogError | None = None

    def __post_init__(self) -> None:
        """失敗イベントとエラー情報の不変条件を検証する。"""

        if self.event == "failed":
            if self.level is not LogLevel.ERROR or self.error is None:
                raise ValueError("failedイベントにはERRORレベルとLogErrorが必要です")
        elif self.error is not None:
            raise ValueError("failed以外のイベントにはLogErrorを設定できません")
