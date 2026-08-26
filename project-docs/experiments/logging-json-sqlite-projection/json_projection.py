"""論理ログをJSONへ直接投影し、JSONから論理ログへ復元する。"""

from __future__ import annotations

from decimal import Decimal
import json

from model import (
    LogicalLog,
    LogicalValue,
    array,
    attributes,
    boolean,
    object_value,
    string,
)


def json_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def encode_json_value(value: LogicalValue) -> str:
    if value.kind == "string":
        return json_string(value.value)
    if value.kind == "number":
        if not value.value.is_finite():
            raise ValueError("JSON number must be finite")
        return str(value.value)
    if value.kind == "boolean":
        return "true" if value.value else "false"
    if value.kind == "array":
        return "[" + ",".join(encode_json_value(item) for item in value.value) + "]"
    if value.kind == "object":
        return "{" + ",".join(
            f"{json_string(name)}:{encode_json_value(item)}"
            for name, item in value.value
        ) + "}"
    raise ValueError(f"unknown logical value kind: {value.kind}")


def encode_json_log(log: LogicalLog) -> str:
    fields = [
        f'"timestamp":{json_string(log.timestamp)}',
        f'"component":{json_string(log.component)}',
        f'"event":{json_string(log.event)}',
        f'"level":{json_string(log.level)}',
    ]
    if log.message is not None:
        fields.append(f'"message":{json_string(log.message)}')
    fields.extend(
        [
            f'"trace_id":{json_string(log.trace_id)}',
            f'"span_id":{json_string(log.span_id)}',
        ]
    )
    if log.attributes:
        encoded_attributes = ",".join(
            f"{json_string(name)}:{encode_json_value(value)}"
            for name, value in log.attributes
        )
        fields.append(f'"attributes":{{{encoded_attributes}}}')
    return "{" + ",".join(fields) + "}"


def reject_duplicate_object_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for name, value in pairs:
        if name in result:
            raise ValueError(f"duplicate JSON object member: {name}")
        result[name] = value
    return result


def decode_json_value(value: object) -> LogicalValue:
    if value is None:
        raise ValueError("null is not a logical attribute value")
    if isinstance(value, bool):
        return boolean(value)
    if isinstance(value, Decimal):
        if not value.is_finite():
            raise ValueError("logical number must be finite")
        return LogicalValue("number", value)
    if isinstance(value, str):
        return string(value)
    if isinstance(value, list):
        return array(*(decode_json_value(item) for item in value))
    if isinstance(value, dict):
        return object_value(*((name, decode_json_value(item)) for name, item in value.items()))
    raise ValueError(f"unsupported JSON value: {type(value).__name__}")


def decode_json_log(text: str) -> LogicalLog:
    def reject_constant(value: str) -> object:
        raise ValueError(f"non-finite JSON number: {value}")

    root = json.loads(
        text,
        parse_int=Decimal,
        parse_float=Decimal,
        parse_constant=reject_constant,
        object_pairs_hook=reject_duplicate_object_pairs,
    )
    if not isinstance(root, dict):
        raise ValueError("JSON log root must be an object")

    required = {"timestamp", "component", "event", "level", "trace_id", "span_id"}
    allowed = required | {"message", "attributes"}
    if required - root.keys():
        raise ValueError(f"missing root fields: {sorted(required - root.keys())}")
    if root.keys() - allowed:
        raise ValueError(f"unexpected root fields: {sorted(root.keys() - allowed)}")

    for name in required:
        if not isinstance(root[name], str):
            raise ValueError(f"{name} must be a JSON string")

    message = root.get("message")
    if message is not None and not isinstance(message, str):
        raise ValueError("message must be a JSON string when present")

    raw_attributes = root.get("attributes", {})
    if not isinstance(raw_attributes, dict):
        raise ValueError("attributes must be a JSON object when present")

    return LogicalLog(
        timestamp=root["timestamp"],
        component=root["component"],
        event=root["event"],
        level=root["level"],
        message=message,
        trace_id=root["trace_id"],
        span_id=root["span_id"],
        attributes=attributes(*(
            (name, decode_json_value(value)) for name, value in raw_attributes.items()
        )),
    )
