#!/usr/bin/env python3
"""JSONとSQLiteの独立投影が同じ論理ログを復元できることを検証する。"""

from __future__ import annotations

import sqlite3

from fixtures import SPAN_ID, TRACE_ID, fixtures
from json_projection import decode_json_log, encode_json_log
from model import LogicalLog, array, attributes, logically_equal, object_value, string
from sqlite_projection import (
    insert_sqlite_log,
    insert_sqlite_value,
    new_database,
    read_sqlite_log,
    read_sqlite_value,
)


def check(condition: bool, name: str) -> None:
    if not condition:
        raise AssertionError(name)
    print(f"PASS {name}")


def expect_error(func, name: str, exc_type: type[BaseException] = Exception) -> None:
    try:
        func()
    except exc_type:
        print(f"PASS {name}")
        return
    raise AssertionError(name)


def verify_roundtrips(all_fixtures: tuple[LogicalLog, ...]) -> None:
    for index, fixture in enumerate(all_fixtures, start=1):
        json_text = encode_json_log(fixture)
        check(
            logically_equal(fixture, decode_json_log(json_text)),
            f"fixture {index}: logical -> JSON -> logical",
        )
        check(
            "\n" not in json_text and "\r" not in json_text,
            f"fixture {index}: JSON is one physical line",
        )

        conn = new_database()
        record_id = insert_sqlite_log(conn, fixture)
        restored = read_sqlite_log(conn, record_id)
        check(
            logically_equal(fixture, restored),
            f"fixture {index}: logical -> SQLite -> logical",
        )
        check(
            not hasattr(restored, "record_id")
            and all(name != "value_id" for name, _ in restored.attributes),
            f"fixture {index}: SQLite local keys do not enter logical log",
        )
        conn.close()


def verify_logical_equality(all_fixtures: tuple[LogicalLog, ...]) -> None:
    reordered_attributes = LogicalLog(
        **{**all_fixtures[0].__dict__, "attributes": tuple(reversed(all_fixtures[0].attributes))}
    )
    check(
        logically_equal(all_fixtures[0], reordered_attributes),
        "attribute order is not logical meaning",
    )

    left_object = object_value(("a", string("1")), ("b", string("2")))
    right_object = object_value(("b", string("2")), ("a", string("1")))
    left = LogicalLog(**{**all_fixtures[1].__dict__, "attributes": attributes(("obj", left_object))})
    right = LogicalLog(**{**all_fixtures[1].__dict__, "attributes": attributes(("obj", right_object))})
    check(logically_equal(left, right), "object member order is not logical meaning")

    left = LogicalLog(
        **{**all_fixtures[1].__dict__, "attributes": attributes(("arr", array(string("a"), string("b"))))}
    )
    right = LogicalLog(
        **{**all_fixtures[1].__dict__, "attributes": attributes(("arr", array(string("b"), string("a"))))}
    )
    check(not logically_equal(left, right), "array order is logical meaning")

    empty_message = LogicalLog(**{**all_fixtures[1].__dict__, "message": ""})
    check(
        not logically_equal(all_fixtures[1], empty_message),
        "absent message and empty message are distinct",
    )


def verify_invalid_json() -> None:
    duplicate = (
        '{"timestamp":"2026-08-26T00:00:00Z","component":"c","event":"e","level":"info",'
        f'"trace_id":"{TRACE_ID}","span_id":"{SPAN_ID}",'
        '"attributes":{"same":1,"same":2}}'
    )
    expect_error(
        lambda: decode_json_log(duplicate),
        "JSON duplicate object member is rejected",
        ValueError,
    )

    null_attribute = (
        '{"timestamp":"2026-08-26T00:00:00Z","component":"c","event":"e","level":"info",'
        f'"trace_id":"{TRACE_ID}","span_id":"{SPAN_ID}",'
        '"attributes":{"invalid":null}}'
    )
    expect_error(
        lambda: decode_json_log(null_attribute),
        "JSON null attribute value is rejected",
        ValueError,
    )


def verify_invalid_sqlite() -> None:
    conn = new_database()
    record_id = insert_sqlite_log(conn, fixtures()[1])
    first = insert_sqlite_value(conn, string("a"))
    second = insert_sqlite_value(conn, string("b"))
    conn.execute(
        "INSERT INTO log_attribute(record_id, name, value_id) VALUES (?, 'same', ?)",
        (record_id, first),
    )
    expect_error(
        lambda: conn.execute(
            "INSERT INTO log_attribute(record_id, name, value_id) VALUES (?, 'same', ?)",
            (record_id, second),
        ),
        "SQLite duplicate attribute name is rejected",
        sqlite3.IntegrityError,
    )
    conn.close()

    conn = new_database()
    parent = insert_sqlite_value(conn, object_value())
    first = insert_sqlite_value(conn, string("a"))
    second = insert_sqlite_value(conn, string("b"))
    conn.execute(
        "INSERT INTO log_object_member(parent_value_id, name, value_id) VALUES (?, 'same', ?)",
        (parent, first),
    )
    expect_error(
        lambda: conn.execute(
            "INSERT INTO log_object_member(parent_value_id, name, value_id) VALUES (?, 'same', ?)",
            (parent, second),
        ),
        "SQLite duplicate object member name is rejected",
        sqlite3.IntegrityError,
    )
    conn.close()

    conn = new_database()
    parent = insert_sqlite_value(conn, array(string("a"), string("b")))
    conn.execute(
        "UPDATE log_array_item SET item_index = 2 WHERE parent_value_id = ? AND item_index = 1",
        (parent,),
    )
    expect_error(
        lambda: read_sqlite_value(conn, parent),
        "SQLite array index gap is rejected on reconstruction",
        ValueError,
    )
    conn.close()

    conn = new_database()
    expect_error(
        lambda: conn.execute(
            "INSERT INTO log_value(value_kind, string_value, number_value) VALUES ('string', 'x', '1')"
        ),
        "SQLite scalar-kind mismatch is rejected",
        sqlite3.IntegrityError,
    )
    conn.close()

    conn = new_database()
    parent = insert_sqlite_value(conn, array())
    child = insert_sqlite_value(conn, string("x"))
    conn.execute(
        "INSERT INTO log_object_member(parent_value_id, name, value_id) VALUES (?, 'invalid', ?)",
        (parent, child),
    )
    expect_error(
        lambda: read_sqlite_value(conn, parent),
        "SQLite relation parent-kind mismatch is rejected on reconstruction",
        ValueError,
    )
    conn.close()

    conn = new_database()
    first = insert_sqlite_value(conn, array())
    second = insert_sqlite_value(conn, array())
    conn.execute(
        "INSERT INTO log_array_item(parent_value_id, item_index, value_id) VALUES (?, 0, ?)",
        (first, second),
    )
    conn.execute(
        "INSERT INTO log_array_item(parent_value_id, item_index, value_id) VALUES (?, 0, ?)",
        (second, first),
    )
    expect_error(
        lambda: read_sqlite_value(conn, first),
        "SQLite cyclic value relation is rejected on reconstruction",
        ValueError,
    )
    conn.close()

    conn = new_database()
    cursor = conn.execute(
        "INSERT INTO log_value(value_kind, number_value) VALUES ('number', 'not-a-number')"
    )
    expect_error(
        lambda: read_sqlite_value(conn, int(cursor.lastrowid)),
        "SQLite invalid numeric text is rejected on reconstruction",
        ValueError,
    )
    conn.close()


def main() -> None:
    print(f"Python sqlite3 SQLite version: {sqlite3.sqlite_version}")
    all_fixtures = fixtures()
    verify_roundtrips(all_fixtures)
    verify_logical_equality(all_fixtures)
    verify_invalid_json()
    verify_invalid_sqlite()
    print("ALL CHECKS PASSED")


if __name__ == "__main__":
    main()
