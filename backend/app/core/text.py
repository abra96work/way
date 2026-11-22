from collections.abc import Callable


def fold(value: str) -> str:
    """Case- and ё-insensitive form for matching Russian names.

    SQLite's LOWER() ignores Cyrillic, so short reference lists are filtered in Python.
    """
    return value.casefold().replace("ё", "е")


def filter_by_name[T](items: list[T], query: str | None, name: Callable[[T], str]) -> list[T]:
    """Keep items whose name contains the query; prefix matches go first."""
    if not query or not query.strip():
        return items
    needle = fold(query.strip())
    matched = [item for item in items if needle in fold(name(item))]
    matched.sort(key=lambda item: not fold(name(item)).startswith(needle))
    return matched
