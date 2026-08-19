from ragscope_ai_service.logging.event_spec import LogLevel


def test_LogLevelは共通契約の4種類を持つ() -> None:
    assert {level.value for level in LogLevel} == {"debug", "info", "warn", "error"}
