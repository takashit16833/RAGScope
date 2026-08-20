from ragscope_ai_service.error.types import AppError, ErrorCategory
from ragscope_ai_service.logging.event_spec import (
    EventSpec,
    FailedEvent,
    LogError,
    NormalEvent,
    NormalLogLevel,
    Payload,
    log_error_from_app_error,
)


def test_LogLevelは共通契約の4種類を持つ() -> None:
    assert {level.value for level in NormalLogLevel} == {"debug", "info", "warn"}


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


def test_NormalEventは通常イベント名と通常ログレベルを保持する() -> None:
    event = NormalEvent(event_name="completed", level=NormalLogLevel.INFO)

    assert event.event_name == "completed"
    assert event.level is NormalLogLevel.INFO


def test_FailedEventはlogErrorだけを保持する() -> None:
    log_error = LogError(
        category=ErrorCategory.DEPENDENCY,
        code="model.unavailable",
        message="Model is unavailable",
    )

    event = FailedEvent(error=log_error)

    assert event.error == log_error
    assert not hasattr(event, "event_name")
    assert not hasattr(event, "level")


def test_EventSpecはoperationとpayloadとevent_kindを保持する() -> None:
    event_kind = NormalEvent(event_name="completed", level=NormalLogLevel.INFO)

    spec = EventSpec(
        operation="embedding.generate",
        payload={"model_id": "example-model"},
        event_kind=event_kind,
    )

    assert spec.operation == "embedding.generate"
    assert spec.payload == {"model_id": "example-model"}
    assert spec.event_kind == event_kind
