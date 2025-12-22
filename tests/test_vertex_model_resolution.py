import os
import unittest

from services.vertex_ai_client import resolve_model_name


class TestVertexModelResolution(unittest.TestCase):
    def setUp(self):
        # Neutralize defaults that may be loaded from .env
        os.environ["DEFAULT_MODEL"] = ""
        for k in ["GITHUB_ACTIONS", "GITHUB_DEFAULT_MODEL", "MODEL_NAME"]:
            if k in os.environ:
                del os.environ[k]

    def test_model_from_env_default(self):
        os.environ["DEFAULT_MODEL"] = "gemini-2.5-flash"
        m = resolve_model_name(None)
        self.assertEqual(m, "gemini-2.5-flash")

    def test_model_from_github_actions(self):
        os.environ["DEFAULT_MODEL"] = ""
        os.environ["GITHUB_ACTIONS"] = "true"
        os.environ["GITHUB_DEFAULT_MODEL"] = "gemini-2.0-pro-exp"
        m = resolve_model_name(None)
        self.assertEqual(m, "gemini-2.0-pro-exp")

    def test_model_pref_parameter_precedence(self):
        os.environ["DEFAULT_MODEL"] = "gemini-2.5-flash"
        m = resolve_model_name("gemini-2.0-flash-exp")
        self.assertEqual(m, "gemini-2.0-flash-exp")

    def test_model_missing_configs_fallback(self):
        os.environ["DEFAULT_MODEL"] = ""
        m = resolve_model_name(None)
        self.assertEqual(m, "gemini-2.0-flash")

    def test_invalid_values_ignored(self):
        os.environ["DEFAULT_MODEL"] = ""
        os.environ["GITHUB_ACTIONS"] = "true"
        os.environ["GITHUB_DEFAULT_MODEL"] = ""
        os.environ["MODEL_NAME"] = ""
        m = resolve_model_name(None)
        self.assertEqual(m, "gemini-2.0-flash")


if __name__ == "__main__":
    unittest.main()
