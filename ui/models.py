# -*- coding: utf-8 -*-
"""List models backing the QML log panel and running task list."""

from __future__ import annotations

from PySide6.QtCore import QAbstractListModel, QByteArray, QModelIndex, Qt, Property, Signal, Slot

LEVEL_GROUPS = {
    "ALL": None,
    "INFO": {"INFO", "SUCCESS"},
    "WARNING": {"WARNING"},
    "ERROR": {"ERROR", "CRITICAL"},
}


class LogModel(QAbstractListModel):
    """Keeps the last ``limit`` log lines and exposes a level-filtered view."""

    LevelRole = Qt.ItemDataRole.UserRole + 1
    MessageRole = Qt.ItemDataRole.UserRole + 2
    TimeRole = Qt.ItemDataRole.UserRole + 3

    filterChanged = Signal()
    countChanged = Signal()

    def __init__(self, limit: int = 1200, parent=None) -> None:
        super().__init__(parent)
        self._limit = limit
        self._entries: list[tuple[str, str, str]] = []
        self._visible: list[int] = []
        self._filter = "ALL"

    def roleNames(self):
        return {
            self.LevelRole: QByteArray(b"level"),
            self.MessageRole: QByteArray(b"message"),
            self.TimeRole: QByteArray(b"time"),
        }

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._visible)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._visible):
            return None
        level, message, time = self._entries[self._visible[index.row()]]
        if role == self.LevelRole:
            return level
        if role in (self.MessageRole, Qt.ItemDataRole.DisplayRole):
            return message
        if role == self.TimeRole:
            return time
        return None

    def _accepts(self, level: str) -> bool:
        group = LEVEL_GROUPS.get(self._filter)
        return group is None or level in group

    def _rebuild(self) -> None:
        self.beginResetModel()
        self._visible = [i for i, entry in enumerate(self._entries) if self._accepts(entry[0])]
        self.endResetModel()
        self.countChanged.emit()

    def append(self, level: str, message: str, time: str = "") -> None:
        if level in ("TRACE", "DEBUG"):
            return
        self._entries.append((level, message, time))
        if len(self._entries) > self._limit:
            del self._entries[: len(self._entries) - self._limit]
            self._rebuild()
            return
        if self._accepts(level):
            row = len(self._visible)
            self.beginInsertRows(QModelIndex(), row, row)
            self._visible.append(len(self._entries) - 1)
            self.endInsertRows()
            self.countChanged.emit()

    def _get_filter(self) -> str:
        return self._filter

    def _set_filter(self, value: str) -> None:
        value = value if value in LEVEL_GROUPS else "ALL"
        if value != self._filter:
            self._filter = value
            self._rebuild()
            self.filterChanged.emit()

    levelFilter = Property(str, _get_filter, _set_filter, notify=filterChanged)
    count = Property(int, lambda self: len(self._visible), notify=countChanged)

    @Slot()
    def clear(self) -> None:
        self.beginResetModel()
        self._entries.clear()
        self._visible.clear()
        self.endResetModel()
        self.countChanged.emit()

    @Slot(result=str)
    def visibleText(self) -> str:
        lines = []
        for i in self._visible:
            level, message, time = self._entries[i]
            lines.append(f"{time} {level:<8} {message}".strip())
        return "\n".join(lines)


class TaskModel(QAbstractListModel):
    """Recently active video/audio tasks with their progress."""

    NameRole = Qt.ItemDataRole.UserRole + 1
    PercentRole = Qt.ItemDataRole.UserRole + 2
    DetailRole = Qt.ItemDataRole.UserRole + 3
    DoneRole = Qt.ItemDataRole.UserRole + 4

    countChanged = Signal()

    def __init__(self, limit: int = 30, parent=None) -> None:
        super().__init__(parent)
        self._limit = limit
        self._items: list[dict] = []

    def roleNames(self):
        return {
            self.NameRole: QByteArray(b"name"),
            self.PercentRole: QByteArray(b"percent"),
            self.DetailRole: QByteArray(b"detail"),
            self.DoneRole: QByteArray(b"done"),
        }

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._items)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._items):
            return None
        item = self._items[index.row()]
        return {
            self.NameRole: item["name"],
            Qt.ItemDataRole.DisplayRole: item["name"],
            self.PercentRole: item["percent"],
            self.DetailRole: item["detail"],
            self.DoneRole: item["done"],
        }.get(role)

    count = Property(int, lambda self: len(self._items), notify=countChanged)

    def _find(self, name: str) -> int:
        for row, item in enumerate(self._items):
            if item["name"] == name:
                return row
        return -1

    def _changed(self, row: int) -> None:
        index = self.index(row)
        self.dataChanged.emit(index, index)

    def upsert(self, name: str, percent: int | None = None, detail: str | None = None, done: bool = False) -> None:
        row = self._find(name)
        if row < 0:
            # Newest first so the active task stays at the top of the list.
            self.beginInsertRows(QModelIndex(), 0, 0)
            self._items.insert(0, {"name": name, "percent": 0, "detail": "", "done": False})
            self.endInsertRows()
            row = 0
            if len(self._items) > self._limit:
                last = len(self._items) - 1
                self.beginRemoveRows(QModelIndex(), last, last)
                self._items.pop()
                self.endRemoveRows()
            self.countChanged.emit()
        item = self._items[row]
        if percent is not None:
            item["percent"] = percent
        if detail is not None:
            item["detail"] = detail
        if done:
            item["done"] = True
            item["percent"] = 100
        self._changed(row)

    def finish_running(self) -> None:
        """Stop showing tasks as running once the worker exits."""
        for row, item in enumerate(self._items):
            if not item["done"]:
                item["detail"] = item["detail"] or "已停止"
                self._changed(row)

    def clear(self) -> None:
        self.beginResetModel()
        self._items.clear()
        self.endResetModel()
        self.countChanged.emit()
