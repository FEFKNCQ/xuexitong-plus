import unittest

from PySide6.QtCore import QCoreApplication
from PySide6.QtTest import QAbstractItemModelTester

from ui.models import LogModel

app = QCoreApplication.instance() or QCoreApplication([])
LEVELS = ["INFO", "WARNING", "ERROR", "SUCCESS", "INFO"]


def rows(model):
    return [model.data(model.index(r, 0), LogModel.MessageRole) for r in range(model.rowCount())]


class LogModelTest(unittest.TestCase):
    def test_trimming_keeps_the_last_lines_without_resets(self):
        for level_filter in ("ALL", "INFO", "WARNING", "ERROR"):
            model = LogModel(limit=7)
            model.levelFilter = level_filter
            QAbstractItemModelTester(model, QAbstractItemModelTester.FailureReportingMode.Fatal)
            resets = []
            model.modelReset.connect(lambda: resets.append(1))
            lines = []
            for i in range(40):
                level = LEVELS[i % len(LEVELS)]
                lines.append((level, f"line {i}"))
                model.append(level, f"line {i}", "12:00:00")
                kept = lines[-7:]
                expected = [m for lv, m in kept if model._accepts(lv)]
                self.assertEqual(rows(model), expected, (level_filter, i))
                self.assertEqual(model.count, len(expected))
            self.assertEqual(resets, [], level_filter)       # no full rebuilds while running

    def test_filter_change_and_clear_still_work(self):
        model = LogModel(limit=5)
        for i in range(12):
            model.append(LEVELS[i % len(LEVELS)], f"line {i}")
        model.levelFilter = "ERROR"
        self.assertEqual(rows(model), ["line 7"])
        model.levelFilter = "ALL"
        self.assertEqual(rows(model), [f"line {i}" for i in range(7, 12)])
        self.assertIn("line 11", model.visibleText())
        model.clear()
        self.assertEqual(model.rowCount(), 0)
        model.append("INFO", "after clear")
        self.assertEqual(rows(model), ["after clear"])


if __name__ == "__main__":
    unittest.main()
