"""外部形式に依存しない論理ログfixtureと同値判定を定義する。"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


@dataclass(frozen=True)
class LogicalValue:
    kind: str
    value: object


@dataclass(frozen=True)
class LogicalLog:
    timestamp: str
    component: str
    event: str
    level: str
    message: str | None
    trace_id: str
    span_id: str
    attributes: tuple[tuple[str, LogicalValue], ...]


def ensure_unique_names(items: Iterable[tuple[str, object]], label: str) -> None:
    seen: set[str] = set()
    for name, _ in items:
        if name in seen:
            raise ValueError(f"duplicate {label}: {name}")
        seen.add(name)


def string(value: str) -> LogicalValue:
    return LogicalValue("string", value)


def number(value: str) -> LogicalValue:
    decimal = Decimal(value)
    if not decimal.is_finite():
        raise ValueError("logical number must be finite")
    return LogicalValue("number", decimal)


def boolean(value: bool) -> LogicalValue:
    return LogicalValue("boolean", value)


def array(*values: LogicalValue) -> LogicalValue:
    return LogicalValue("array", tuple(values))


def object_value(*members: tuple[str, LogicalValue]) -> LogicalValue:
    ensure_unique_names(members, "object member")
    return LogicalValue("object", tuple(members))


def attributes(*items: tuple[str, LogicalValue]) -> tuple[tuple[str, LogicalValue], ...]:
    ensure_unique_names(items, "attribute")
    return tuple(items)


def normalized_value(value: LogicalValue) -> object:
    if value.kind in {"string", "number", "boolean"}:
        return (value.kind, value.value)
    if value.kind == "array":
        return ("array", tuple(normalized_value(item) for item in value.value))
    if value.kind == "object":
        return (
            "object",
            frozenset((name, normalized_value(item)) for name, item in value.value),
        )
    raise ValueError(f"unknown logical value kind: {value.kind}")


def normalized_log(log: LogicalLog) -> object:
    return (
        log.timestamp,
        log.component,
        log.event,
        log.level,
        log.message,
        log.trace_id,
        log.span_id,
        frozenset((name, normalized_value(value)) for name, value in log.attributes),
    )


def logically_equal(left: LogicalLog, right: LogicalLog) -> bool:
    return normalized_log(left) == normalized_log(right)
