from ragscope_ai_service.error.types import AppError, ErrorCategory
from ragscope_ai_service.logging.event_spec import (
    LogError,
    LogLevel,
    Payload,
    log_error_from_app_error,
)


def test_LogLevelは共通契約の4種類を持つ() -> None:
    assert {level.value for level in LogLevel} == {"debug", "info", "warn", "error"}


def test_Payloadはnullを含まないログ記録可能な値を保持できる() -> None:
    payload: Payload = {
        "model_id": "example-model",
        "token_count": 123,
        "cached": False,
        "durations_ms": (10.5, 20.5),
        "detail": {
            "batch_count": 3,
        },
    }

    assert payload["model_id"] == "example-model"


def test_AppErrorから安全なログ情報だけを投影する() -> None:
    cause = RuntimeError("private technical detail")

    app_error = AppError(
        category=ErrorCategory.DEPENDENCY,
        code="model.unavailable",
        message="Model is unavailable",
        context={"model_id": "example-model"},
        cause=cause,
    )

    log_error = log_error_from_app_error(app_error)

    assert log_error == LogError(
        category=ErrorCategory.DEPENDENCY,
        code="model.unavailable",
        message="Model is unavailable",
        context={"model_id": "example-model"},
    )

    assert not hasattr(log_error, "cause")
