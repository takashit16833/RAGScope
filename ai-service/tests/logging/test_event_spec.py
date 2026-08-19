from ragscope_ai_service.logging.event_spec import LogLevel, Payload


def test_LogLevelは共通契約の4種類を持つ() -> None:
    assert {level.value for level in LogLevel} == {"debug", "info", "warn", "error"}


def test_Payloadはnullを含まないJSON相当値を保持できる() -> None:
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
