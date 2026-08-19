from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class ExecutionContext:
    """1回のCLIコマンドに属するログイベントの文脈。"""

    execution_id: UUID


@dataclass(frozen=True)
class ServiceContext:
    """サービスの起動・終了などの状態変化に属するログイベントの文脈。"""


type EventContext = ExecutionContext | ServiceContext
