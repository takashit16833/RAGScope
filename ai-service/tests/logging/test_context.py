from uuid import UUID

from ragscope_ai_service.logging.context import ExecutionContext, ServiceContext


def test_ExecutionContextがexecution_idを保持する() -> None:
    execution_id = UUID("7d9c35b8-7980-4b20-a86c-7220e67276cc")

    context = ExecutionContext(execution_id=execution_id)

    assert context.execution_id == execution_id


def test_ServiceContextはexecution_idを持たない() -> None:
    context = ServiceContext()

    assert not hasattr(context, "execution_id")
