import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("bridge", Path(__file__).parents[1] / "tools" / "claude-statusline.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class StatuslineTests(unittest.TestCase):
    def test_filters_sensitive_fields(self):
        result = bridge.snapshot({"transcript_path": "/private", "session_id": "secret",
            "rate_limits": {"five_hour": {"used_percentage": 25, "resets_at": 1800000000, "secret": "no"}}})
        self.assertEqual(result, {"rate_limits": {"five_hour": {"used_percentage": 25, "resets_at": 1800000000}}})
    def test_missing_is_not_zero(self):
        self.assertEqual(bridge.snapshot({}), {"rate_limits": {}})
    def test_invalid_percent_rejected(self):
        for value in (-1, 101, "20", True, float("nan")):
            self.assertEqual(bridge.snapshot({"rate_limits": {"five_hour": {"used_percentage": value}}}), {"rate_limits": {}})
    def test_windows_independently_optional(self):
        self.assertEqual(bridge.snapshot({"rate_limits": {"seven_day": {"used_percentage": 0}}}),
                         {"rate_limits": {"seven_day": {"used_percentage": 0}}})
