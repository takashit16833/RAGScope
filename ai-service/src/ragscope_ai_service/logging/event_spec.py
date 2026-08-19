from collections.abc import Mapping
from enum import StrEnum

type LogValue = str | int | float | bool | tuple[LogValue, ...] | Mapping[str, LogValue]


type Payload = Mapping[str, LogValue]


class LogLevel(StrEnum):
    DEBUG = "debug"
    INFO = "info"
    WARN = "warn"
    ERROR = "error"
