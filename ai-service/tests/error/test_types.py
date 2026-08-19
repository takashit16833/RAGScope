from ragscope_ai_service.error.types import AppError, ErrorCategory


def test_ErrorCategoryの値が共通契約と一致する() -> None:
    # Enumの外部表現が増減・変更されても、共通エラー契約との差異を検出できるようにする。
    actual_values = {category.value for category in ErrorCategory}

    assert actual_values == {
        "input",
        "resource",
        "data",
        "dependency",
        "timeout",
        "internal",
    }


def test_AppErrorが共通エラー情報を保持する() -> None:
    cause = RuntimeError("private technical detail")

    error = AppError(
        category=ErrorCategory.DEPENDENCY,
        code="model.unavailable",
        message="The model is unavailable",
        context={"model_id": "example"},
        cause=cause,
    )

    # AppErrorへ渡した公開可能な情報が、そのまま保持されることを確認する。
    assert error.category is ErrorCategory.DEPENDENCY
    assert error.code == "model.unavailable"
    assert error.message == "The model is unavailable"
    assert error.context == {"model_id": "example"}

    # 元の技術的例外は、別の例外へ変換せず同一オブジェクトとして保持する。
    assert error.cause is cause


def test_AppErrorのreprにcauseを含めない() -> None:
    error = AppError(
        category=ErrorCategory.INTERNAL,
        code="model.failed",
        message="The model operation failed.",
        cause=RuntimeError("private technical detail"),
    )

    # causeの内容が、dataclassの開発者向け表示から不用意に漏れないことを確認する。
    assert "private technical detail" not in repr(error)
