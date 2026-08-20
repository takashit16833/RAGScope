from enum import Enum, auto


class SchemaVersion(Enum):
    """構造化ログの契約バージョン。"""

    V1 = auto()


class Component(Enum):
    """ログイベントを生成したコンポーネント。"""

    AI_SERVICE = auto()
