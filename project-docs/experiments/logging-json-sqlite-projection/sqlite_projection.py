"""論理ログをSQLiteへ直接投影し、SQLiteから論理ログへ復元する。"""

from __future__ import annotations

from decimal import Decimal
import sqlite3

from model import (
    LogicalLog,
    LogicalValue,
    array,
    attributes,
    boolean,
    object_value,
    string,
)


SQLITE_SCHEMA = r"""
PRAGMA foreign_keys = ON;

CREATE TABLE log_record (
    record_id INTEGER PRIMARY KEY,
    timestamp TEXT NOT NULL,
    component TEXT NOT NULL,
    event TEXT NOT NULL,
    level TEXT NOT NULL,
    message TEXT,
    trace_id TEXT NOT NULL,
    span_id TEXT NOT NULL
) STRICT;

CREATE TABLE log_value (
    value_id INTEGER PRIMARY KEY,
    value_kind TEXT NOT NULL CHECK (value_kind IN ('string', 'number', 'boolean', 'array', 'object')),
    string_value TEXT,
    number_value TEXT,
    boolean_value INTEGER,
    CHECK (
        (value_kind = 'string' AND string_value IS NOT NULL AND number_value IS NULL AND boolean_value IS NULL)
        OR (value_kind = 'number' AND string_value IS NULL AND number_value IS NOT NULL AND boolean_value IS NULL)
        OR (value_kind = 'boolean' AND string_value IS NULL AND number_value IS NULL AND boolean_value IN (0, 1))
        OR (value_kind IN ('array', 'object') AND string_value IS NULL AND number_value IS NULL AND boolean_value IS NULL)
    )
) STRICT;

CREATE TABLE log_attribute (
    record_id INTEGER NOT NULL REFERENCES log_record(record_id),
    name TEXT NOT NULL,
    value_id INTEGER NOT NULL REFERENCES log_value(value_id),
    PRIMARY KEY (record_id, name)
) STRICT;

CREATE TABLE log_array_item (
    parent_value_id INTEGER NOT NULL REFERENCES log_value(value_id),
    item_index INTEGER NOT NULL CHECK (item_index >= 0),
    value_id INTEGER NOT NULL REFERENCES log_value(value_id),
    PRIMARY KEY (parent_value_id, item_index)
) STRICT;

CREATE TABLE log_object_member (
    parent_value_id INTEGER NOT NULL REFERENCES log_value(value_id),
    name TEXT NOT NULL,
    value_id INTEGER NOT NULL REFERENCES log_value(value_id),
    PRIMARY KEY (parent_value_id, name)
) STRICT;
"""


def new_database() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.executescript(SQLITE_SCHEMA)
    return conn


def insert_sqlite_value(conn: sqlite3.Connection, value: LogicalValue) -> int:
    if value.kind == "string":
        cursor = conn.execute(
            "INSERT INTO log_value(value_kind, string_value) VALUES ('string', ?)",
            (value.value,),
        )
    elif value.kind == "number":
        cursor = conn.execute(
            "INSERT INTO log_value(value_kind, number_value) VALUES ('number', ?)",
            (str(value.value),),
        )
    elif value.kind == "boolean":
        cursor = conn.execute(
            "INSERT INTO log_value(value_kind, boolean_value) VALUES ('boolean', ?)",
            (1 if value.value else 0,),
        )
    elif value.kind in {"array", "object"}:
        cursor = conn.execute(
            "INSERT INTO log_value(value_kind) VALUES (?)",
            (value.kind,),
        )
    else:
        raise ValueError(f"unknown logical value kind: {value.kind}")

    value_id = int(cursor.lastrowid)
    if value.kind == "array":
        for index, item in enumerate(value.value):
            child_id = insert_sqlite_value(conn, item)
            conn.execute(
                "INSERT INTO log_array_item(parent_value_id, item_index, value_id) VALUES (?, ?, ?)",
                (value_id, index, child_id),
            )
    elif value.kind == "object":
        for name, item in value.value:
            child_id = insert_sqlite_value(conn, item)
            conn.execute(
                "INSERT INTO log_object_member(parent_value_id, name, value_id) VALUES (?, ?, ?)",
                (value_id, name, child_id),
            )
    return value_id


def insert_sqlite_log(conn: sqlite3.Connection, log: LogicalLog) -> int:
    with conn:
        cursor = conn.execute(
            """
            INSERT INTO log_record(timestamp, component, event, level, message, trace_id, span_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                log.timestamp,
                log.component,
                log.event,
                log.level,
                log.message,
                log.trace_id,
                log.span_id,
            ),
        )
        record_id = int(cursor.lastrowid)
        for name, value in log.attributes:
            value_id = insert_sqlite_value(conn, value)
            conn.execute(
                "INSERT INTO log_attribute(record_id, name, value_id) VALUES (?, ?, ?)",
                (record_id, name, value_id),
            )
    return record_id


def relation_counts(conn: sqlite3.Connection, value_id: int) -> tuple[int, int]:
    array_count = conn.execute(
        "SELECT COUNT(*) FROM log_array_item WHERE parent_value_id = ?", (value_id,)
    ).fetchone()[0]
    object_count = conn.execute(
        "SELECT COUNT(*) FROM log_object_member WHERE parent_value_id = ?", (value_id,)
    ).fetchone()[0]
    return array_count, object_count


def read_sqlite_value(
    conn: sqlite3.Connection,
    value_id: int,
    path: frozenset[int] = frozenset(),
) -> LogicalValue:
    if value_id in path:
        raise ValueError("cyclic SQLite value relation")
    row = conn.execute(
        "SELECT value_kind, string_value, number_value, boolean_value FROM log_value WHERE value_id = ?",
        (value_id,),
    ).fetchone()
    if row is None:
        raise ValueError(f"missing log_value: {value_id}")

    kind, string_value, number_value, boolean_value = row
    array_children, object_children = relation_counts(conn, value_id)
    next_path = path | {value_id}

    if kind == "string":
        reject_scalar_children(array_children, object_children)
        return string(string_value)
    if kind == "number":
        reject_scalar_children(array_children, object_children)
        try:
            decimal = Decimal(number_value)
        except Exception as exc:
            raise ValueError(f"invalid SQLite number: {number_value}") from exc
        if not decimal.is_finite():
            raise ValueError("SQLite number must be finite")
        return LogicalValue("number", decimal)
    if kind == "boolean":
        reject_scalar_children(array_children, object_children)
        return boolean(bool(boolean_value))
    if kind == "array":
        if object_children:
            raise ValueError("array SQLite value must not have object-member relations")
        rows = conn.execute(
            "SELECT item_index, value_id FROM log_array_item WHERE parent_value_id = ? ORDER BY item_index",
            (value_id,),
        ).fetchall()
        actual_indexes = [item_index for item_index, _ in rows]
        if actual_indexes != list(range(len(rows))):
            raise ValueError(f"array indexes must be contiguous from 0: {actual_indexes}")
        return array(*(read_sqlite_value(conn, child_id, next_path) for _, child_id in rows))
    if kind == "object":
        if array_children:
            raise ValueError("object SQLite value must not have array-item relations")
        rows = conn.execute(
            "SELECT name, value_id FROM log_object_member WHERE parent_value_id = ? ORDER BY name",
            (value_id,),
        ).fetchall()
        return object_value(*(
            (name, read_sqlite_value(conn, child_id, next_path)) for name, child_id in rows
        ))
    raise ValueError(f"unknown SQLite value_kind: {kind}")


def reject_scalar_children(array_children: int, object_children: int) -> None:
    if array_children or object_children:
        raise ValueError("scalar SQLite value must not have child relations")


def read_sqlite_log(conn: sqlite3.Connection, record_id: int) -> LogicalLog:
    row = conn.execute(
        """
        SELECT timestamp, component, event, level, message, trace_id, span_id
        FROM log_record
        WHERE record_id = ?
        """,
        (record_id,),
    ).fetchone()
    if row is None:
        raise ValueError(f"missing log_record: {record_id}")

    attr_rows = conn.execute(
        "SELECT name, value_id FROM log_attribute WHERE record_id = ? ORDER BY name",
        (record_id,),
    ).fetchall()
    return LogicalLog(
        timestamp=row[0],
        component=row[1],
        event=row[2],
        level=row[3],
        message=row[4],
        trace_id=row[5],
        span_id=row[6],
        attributes=attributes(*(
            (name, read_sqlite_value(conn, value_id)) for name, value_id in attr_rows
        )),
    )
