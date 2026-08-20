from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum

from ragscope_ai_service.error.types import AppError, ErrorCategory, ErrorContext

type LogValue = str | int | float | bool | tuple[LogValue, ...] | Mapping[str, LogValue]


type Payload = Mapping[str, LogValue]


class NormalLogLevel(StrEnum):
    """通常イベントで指定できるログレベル"""

    DEBUG = "debug"
    INFO = "info"
    WARN = "warn"


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
class NormalEvent:
    """通常イベントの名前とログレベル。"""

    event_name: str
    level: NormalLogLevel


@dataclass(frozen=True)
class FailedEvent:
    """処理の失敗と安全なエラー情報。"""

    error: LogError


type EventKind = NormalEvent | FailedEvent


@dataclass(frozen=True)
class EventSpec:
    """機能側で意味が確定したログイベント。"""

    operation: str
    payload: Payload
    event_kind: EventKind
