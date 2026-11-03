import configparser
import unittest
from pathlib import Path

from ui import advanced

TEMPLATE = Path(__file__).resolve().parent.parent / "config_template.ini"


def template() -> configparser.ConfigParser:
    config = configparser.ConfigParser(interpolation=None)
    config.read(TEMPLATE, encoding="utf-8")
    return config


class AdvancedOptionsTest(unittest.TestCase):
    def test_fields_unique_and_typed(self):
        ids = [f["id"] for f in advanced.fields()]
        self.assertEqual(len(ids), len(set(ids)))
        types = {"providers", "switch", "percent", "number", "choice", "text", "secret"}
        for f in advanced.fields():
            self.assertIn(f["type"], types, f["id"])
            if f["type"] == "number":
                self.assertLessEqual(f["min"], f["max"])

    def test_show_conditions_point_at_fields(self):
        ids = {f["id"] for f in advanced.fields()}
        for group in advanced.GROUPS:
            for f in group["fields"]:
                if "show" in f:
                    self.assertIn(f["show"]["key"], ids, f)

    def test_provider_options_exist_in_worker(self):
        import api.answer as answer
        import api.notification as notification
        for option in advanced.TIKU_PROVIDERS:
            self.assertTrue(hasattr(answer, option["value"]), option)
        for option in advanced.NOTIFY_PROVIDERS:
            if option["value"]:
                self.assertTrue(hasattr(notification, option["value"]), option)

    def test_template_round_trip_is_unchanged(self):
        config = template()
        before = {s: dict(config[s]) for s in config.sections()}
        before["notification"]["tg_chat_id"] = ""   # template placeholder XXXXXX is cleared
        advanced.write_values(config, advanced.read_values(config))
        self.assertEqual({s: dict(config[s]) for s in config.sections()}, before)

    def test_placeholder_reads_empty(self):
        values = advanced.read_values(template())
        self.assertEqual(values["notification.tg_chat_id"], "")
        self.assertEqual(values["tiku.provider"], "TikuAdapter")
        self.assertEqual(values["tiku.cover_rate"], "0.9")

    def test_defaults_not_added_but_changes_are(self):
        config = configparser.ConfigParser(interpolation=None)
        values = advanced.read_values(config)
        values["common.work_redo_enabled"] = "true"
        advanced.write_values(config, values)
        self.assertEqual(config["common"]["work_redo_enabled"], "true")
        self.assertFalse(config.has_option("common", "work_max_retries"))   # still the default
        self.assertFalse(config.has_option("tiku", "submit"))

    def test_answer_mode(self):
        self.assertEqual(advanced.answer_mode(""), "none")
        self.assertEqual(advanced.answer_mode("TikuYanxi,TikuGo"), "tiku")
        self.assertEqual(advanced.answer_mode("AI"), "ai")
        self.assertEqual(advanced.answer_mode("TikuYanxi, SiliconFlow"), "both")

    def test_apply_answer_mode_keeps_fitting_picks(self):
        self.assertEqual(advanced.apply_answer_mode("TikuGo,AI", "tiku"), "TikuGo")
        self.assertEqual(advanced.apply_answer_mode("TikuGo,AI", "ai"), "AI")
        self.assertEqual(advanced.apply_answer_mode("TikuGo", "both"), "TikuGo,AI")        # default AI added
        self.assertEqual(advanced.apply_answer_mode("SiliconFlow", "both"), "TikuYanxi,SiliconFlow")
        self.assertEqual(advanced.apply_answer_mode("TikuGo", "ai"), "AI")
        self.assertEqual(advanced.apply_answer_mode("TikuGo,AI", "none"), "")
        for mode in ("tiku", "ai", "both"):
            self.assertEqual(advanced.answer_mode(advanced.apply_answer_mode("", mode)), mode)

    def test_order_providers_puts_tiku_first(self):
        self.assertEqual(advanced.order_providers(["AI", "TikuGo", "SiliconFlow", "TikuYanxi"]),
                         "TikuGo,TikuYanxi,AI,SiliconFlow")

    def test_normalize(self):
        self.assertEqual(advanced.normalize("x", True), "true")
        self.assertEqual(advanced.normalize("x", False), "false")
        self.assertEqual(advanced.normalize("x", ["TikuYanxi", " AI ", ""]), "TikuYanxi,AI")
        self.assertEqual(advanced.normalize("x", 0.85), "0.85")
        self.assertEqual(advanced.normalize("x", "abc"), "abc")


if __name__ == "__main__":
    unittest.main()
