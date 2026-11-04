import os
import tempfile
import unittest

from api.answer import Tiku, TikuFallback
from ui.controller import build_work_view


class FakeBank(Tiku):
    def __init__(self, answers):
        super().__init__()
        self.name = "fake-bank"
        self.answers = answers
        self.skip_answer_validation = True

    def _init_tiku(self):
        pass

    def _query(self, q_info):
        return self.answers.get(q_info["title"])


class FakeAI(FakeBank):
    ORIGIN = "ai"


class AnswerOriginTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cwd = os.getcwd()
        os.chdir(self.tmp.name)            # cache.json / cache_origin.json go here

    def tearDown(self):
        os.chdir(self.cwd)
        self.tmp.cleanup()

    def questions(self):
        return [{"title": t, "type": "completion", "options": ""} for t in ("题目一", "题目二", "题目三")]

    def test_fallback_records_who_answered(self):
        chain = TikuFallback([FakeBank({"题目一": "甲"}), FakeAI({"题目一": "乙", "题目二": "丙"})])
        answers = chain.query_all(self.questions())
        self.assertEqual(answers, ["甲", "丙", None])
        self.assertEqual(chain.last_origins, ["tiku", "ai", None])

    def test_cache_hits_keep_their_origin(self):
        TikuFallback([FakeAI({"题目二": "丙"})]).query_all(self.questions())
        # Second run: nothing answers any more, so 题目二 comes from the cache.
        chain = TikuFallback([FakeBank({})])
        answers = chain.query_all(self.questions())
        self.assertEqual(answers[1], "丙")
        self.assertEqual(chain.last_origins[1], "ai")

    def test_old_cache_without_origin_counts_as_bank(self):
        with open("cache.json", "w", encoding="utf8") as fp:
            fp.write('{"题目三": "丁"}')
        chain = TikuFallback([FakeBank({})])
        chain.query_all(self.questions())
        self.assertEqual(chain.last_origins[2], "tiku")


class BadgeTest(unittest.TestCase):
    def test_badges(self):
        view = build_work_view({"questions": [
            {"type": "completion", "title": "a", "answer": "x", "source": "cover", "origin": "ai"},
            {"type": "completion", "title": "b", "answer": "y", "source": "cover", "origin": "tiku"},
            {"type": "completion", "title": "c", "answer": "z", "source": "random", "origin": ""},
        ]})
        q = view["questions"]
        self.assertEqual([(x["fromBank"], x["fromAI"]) for x in q], [(True, True), (True, False), (False, False)])


if __name__ == "__main__":
    unittest.main()
