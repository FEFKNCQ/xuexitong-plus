import contextlib
import io
import json
import os
import unittest
from unittest import mock

from ui.output_parser import (
    ActivityEvent,
    CourseListEvent,
    LogEvent,
    OutputParser,
    ProgressEvent,
    PromptEvent,
    VideoPreviewEvent,
    WorkPreviewEvent,
    strip_ansi,
)

LOGURU = "\x1b[32m2026-11-03 17:43:04.123\x1b[0m | \x1b[1mINFO    \x1b[0m | api.base:study:1 - \x1b[1m{}\x1b[0m"


def of_type(events, cls):
    return [e for e in events if isinstance(e, cls)]


class OutputParserTestCase(unittest.TestCase):
    def setUp(self):
        self.parser = OutputParser()

    def test_strip_ansi(self):
        self.assertEqual(strip_ansi("\x1b[1;31mabc\x1b[0m\x1b[A"), "abc")

    def test_loguru_line_with_colors(self):
        events = self.parser.feed(LOGURU.format("登录成功") + "\n")
        logs = of_type(events, LogEvent)
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0].level, "INFO")
        self.assertEqual(logs[0].message, "登录成功")
        self.assertEqual(logs[0].time, "17:43:04")

    def test_continuation_line_keeps_level(self):
        line = LOGURU.format("boom").replace("INFO    ", "ERROR   ")
        events = self.parser.feed(line + "\nTraceback (most recent call last):\n")
        logs = of_type(events, LogEvent)
        self.assertEqual([e.level for e in logs], ["ERROR", "ERROR"])

    def test_activity_markers(self):
        events = self.parser.feed(
            LOGURU.format("开始学习课程: 大学物理") + "\n"
            + LOGURU.format("当前章节: 1.1 质点") + "\n"
            + LOGURU.format("开始任务: a.mp4, 总时长: 40s, 已进行: 0s") + "\n"
            + LOGURU.format("任务完成: a.mp4") + "\n"
        )
        activities = [(e.kind, e.value) for e in of_type(events, ActivityEvent)]
        self.assertEqual(activities, [
            ("course", "大学物理"),
            ("chapter", "1.1 质点"),
            ("task_started", "a.mp4"),
            ("task_finished", "a.mp4"),
        ])

    def test_tqdm_progress_with_carriage_returns(self):
        events = self.parser.feed("\ra.mp4:  10%|█         | 00:04/00:40\ra.mp4:  50%|█████     | 00:20/00:40")
        self.assertEqual([e.percent for e in of_type(events, ProgressEvent)], [10])
        events = self.parser.feed("\n")
        progress = of_type(events, ProgressEvent)
        self.assertEqual(progress[0].percent, 50)
        self.assertEqual((progress[0].name, progress[0].done, progress[0].total), ("a.mp4", "00:20", "00:40"))
        self.assertFalse(of_type(events, LogEvent))

    def test_video_preview(self):
        payload = json.dumps({"source": "https://a.chaoxing.com/v.mp4", "title": "v"}, ensure_ascii=False)
        events = self.parser.feed("__CX_VIDEO_PREVIEW__" + payload + "\n__CX_VIDEO_PREVIEW__{bad\n")
        previews = of_type(events, VideoPreviewEvent)
        self.assertEqual((previews[0].source, previews[0].title, previews[0].valid), ("https://a.chaoxing.com/v.mp4", "v", True))
        self.assertFalse(previews[1].valid)
        self.assertFalse(of_type(events, LogEvent))

    def test_work_preview(self):
        payload = json.dumps({"phase": "filled", "questions": [{"index": 1}]})
        events = self.parser.feed("__CX_WORK_PREVIEW__" + payload + "\n__CX_WORK_PREVIEW__[]\n")
        work = of_type(events, WorkPreviewEvent)
        self.assertEqual(work[0].phase, "filled")
        self.assertEqual(work[0].data["questions"], [{"index": 1}])
        self.assertFalse(work[1].valid)

    def test_course_list_and_prompt(self):
        text = (
            "**********课程列表**********\n"
            "ID: 2151141 班级ID: 9001 课程名: 大学物理（上）\n"
            "ID: 189191 班级ID: 9002 课程名: 马原\n"
            "****************************\n"
            "提示: 同一 courseId 下若存在多个班级, 将分别完成。\n"
            "请输入想要学习的课程列表,以逗号分隔,例: 2151141,189191,198198\n"
        )
        events = self.parser.feed(text)
        self.assertFalse(of_type(events, LogEvent))
        courses = of_type(events, CourseListEvent)
        self.assertEqual(len(courses), 1)
        self.assertEqual(courses[0].courses[0], {"courseId": "2151141", "clazzId": "9001", "title": "大学物理（上）"})
        self.assertEqual(len(courses[0].courses), 2)

    def test_yes_no_prompt_without_newline(self):
        prompt = "大模型连接检查失败，无法准确答题，是否继续运行？(Y/n): "
        events = self.parser.feed(prompt)
        self.assertEqual([e.text for e in of_type(events, PromptEvent)], [prompt.strip()])
        # Feeding more data without the answer must not re-raise the prompt.
        self.assertFalse(of_type(self.parser.feed(""), PromptEvent))
        events = self.parser.feed(LOGURU.format("继续") + "\n")
        logs = of_type(events, LogEvent)
        self.assertEqual([(e.level, e.message) for e in logs], [("WARNING", prompt.strip()), ("INFO", "继续")])

    def test_final_flushes_partial_line(self):
        self.assertFalse(self.parser.feed("tail without newline"))
        events = self.parser.feed("", final=True)
        self.assertEqual([e.message for e in of_type(events, LogEvent)], ["tail without newline"])


class StreamDecoderTestCase(unittest.TestCase):
    def test_utf8_split_across_reads(self):
        from ui.output_parser import StreamDecoder

        data = "登录成功\n".encode("utf-8")
        d = StreamDecoder()
        text = d.decode(data[:2]) + d.decode(data[2:5]) + d.decode(data[5:], final=True)
        self.assertEqual(text, "登录成功\n")
        self.assertEqual(d.encoding, "utf-8")

    def test_falls_back_to_gbk(self):
        from ui.output_parser import StreamDecoder

        d = StreamDecoder()
        first = d.decode("用法: chaoxing-worker.exe\n".encode("gbk"))
        rest = d.decode("当前章节: 1.1\n".encode("gbk"), final=True)
        self.assertEqual(first + rest, "用法: chaoxing-worker.exe\n当前章节: 1.1\n")
        self.assertEqual(d.encoding, "gb18030")

    def test_gbk_starting_like_utf8_lead_byte(self):
        from ui.output_parser import StreamDecoder

        # "开始" in GBK is C1 F7 ... ; an incomplete-looking first read must not lose bytes.
        raw = "开始学习课程: 大学物理\n".encode("gbk")
        d = StreamDecoder()
        out = "".join(d.decode(raw[i:i + 1]) for i in range(len(raw))) + d.decode(b"", final=True)
        self.assertEqual(out, "开始学习课程: 大学物理\n")


class WorkPreviewEmitTestCase(unittest.TestCase):
    def test_emit_respects_flag_and_never_raises(self):
        from api.base import _emit_work_preview, _work_preview_questions

        out = io.StringIO()
        with mock.patch.dict(os.environ, {"CHAOXING_DESKTOP_PREVIEW": ""}), contextlib.redirect_stdout(out):
            _emit_work_preview({"phase": "filled"})
        self.assertEqual(out.getvalue(), "")

        out = io.StringIO()
        with mock.patch.dict(os.environ, {"CHAOXING_DESKTOP_PREVIEW": "1"}), contextlib.redirect_stdout(out):
            _emit_work_preview({"phase": "saved", "obj": object()})
        self.assertTrue(out.getvalue().startswith("__CX_WORK_PREVIEW__"))

        self.assertEqual(_work_preview_questions(None), [])
        q = {"id": "7", "type": "single", "title": "t", "options": "A. x", "answerField": {"answer7": "A"},
             "answerSource7": "cover"}
        self.assertEqual(_work_preview_questions([q, "bad"])[0]["answer"], "A")



class GluedPreviewTestCase(unittest.TestCase):
    def test_preview_after_progress_bar(self):
        # tqdm leaves its bar without a line end, so the next print is glued to it.
        parser = OutputParser()
        quiz = json.dumps({"phase": "questions", "questions": [{"index": 1, "title": "越剧的发源地是（）"}]}, ensure_ascii=False)
        video = json.dumps({"source": "https://s2.cldisk.com/a.mp4", "title": "3.2.mp4"}, ensure_ascii=False)
        cr, lf = chr(13), chr(10)
        events = parser.feed(cr + "3.1认识越剧.mp4:  50%|█████     | 06:22/12:44__CX_WORK_PREVIEW__" + quiz + lf
                             + cr + "3.1认识越剧.mp4:  51%|█████     | 06:30/12:44__CX_VIDEO_PREVIEW__" + video + lf)
        kinds = [type(e).__name__ for e in events]
        self.assertEqual(kinds, ["ProgressEvent", "WorkPreviewEvent", "ProgressEvent", "VideoPreviewEvent"])
        self.assertEqual(events[1].phase, "questions")
        self.assertEqual(events[0].done, "06:22")
        self.assertEqual(events[3].title, "3.2.mp4")

class ClockSecondsTestCase(unittest.TestCase):
    def test_formats(self):
        from ui.output_parser import clock_seconds

        self.assertEqual(clock_seconds("01:57"), 117)
        self.assertEqual(clock_seconds("1:02:03"), 3723)
        self.assertEqual(clock_seconds("432"), 432)
        self.assertIsNone(clock_seconds("1.08k"))
        self.assertIsNone(clock_seconds(""))

if __name__ == "__main__":
    unittest.main()
