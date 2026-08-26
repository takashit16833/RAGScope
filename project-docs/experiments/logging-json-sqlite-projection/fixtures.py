"""JSON/SQLiteの両方へ同じ入力として渡す論理ログfixtureを定義する。"""

from model import LogicalLog, array, attributes, boolean, number, object_value, string

TRACE_ID = "4bf92f3577b34da6a3ce929d0e0e4736"
SPAN_ID = "00f067aa0ba902b7"


def fixtures() -> tuple[LogicalLog, ...]:
    return (
        LogicalLog(
            timestamp="2026-08-26T00:00:02.123456Z",
            component="example_component",
            event="document.read.failed",
            level="error",
            message="line1\nline2\t\"quoted\"\\path",
            trace_id=TRACE_ID,
            span_id=SPAN_ID,
            attributes=attributes(
                ("error_type", string("document.file_not_found")),
                ("document_version_id", string("document-version-001")),
                ("large_integer", number("9007199254740993")),
                ("precise_decimal", number("0.123456789012345678901234567890")),
                ("cache_hit", boolean(False)),
                (
                    "mixed",
                    array(
                        string("a"),
                        number("-12.50"),
                        boolean(True),
                        object_value(
                            ("nested_array", array(number("1"), number("2.25"))),
                            ("nested_object", object_value(("label", string("x")))),
                        ),
                        array(),
                        object_value(),
                    ),
                ),
                ("empty_array", array()),
                ("empty_object", object_value()),
            ),
        ),
        LogicalLog(
            timestamp="2026-08-26T00:00:03Z",
            component="example_component",
            event="example.process.succeeded",
            level="info",
            message=None,
            trace_id=TRACE_ID,
            span_id="00f067aa0ba902b8",
            attributes=attributes(),
        ),
        LogicalLog(
            timestamp="2026-08-26T00:00:04Z",
            component="example_component",
            event="example.process.succeeded",
            level="info",
            message="",
            trace_id=TRACE_ID,
            span_id="00f067aa0ba902b9",
            attributes=attributes(
                ("empty_string", string("")),
                ("control_string", string("newline\ncarriage\rreturn\ttab")),
            ),
        ),
    )
