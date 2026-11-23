import unittest
from unittest.mock import patch

from firebase_functions import https_fn

from main import _require_network_admin, _require_system_admin, _require_threat_admin


class UnknownRoleTests(unittest.TestCase):
    def test_unknown_roles_are_rejected_with_explicit_403(self):
        for require_role in (
            _require_network_admin,
            _require_system_admin,
            _require_threat_admin,
        ):
            with self.subTest(require_role=require_role.__name__), patch(
                "main._require_active_user",
                return_value={"roleId": "role_owner"},
            ):
                with self.assertRaises(https_fn.HttpsError) as raised:
                    require_role(object())
                self.assertIn("Unknown user role", raised.exception.message)


class CorsTests(unittest.TestCase):
    def test_allowlist_parser_shape(self):
        raw = "http://localhost:8000,https://netvision-ai-0.web.app"
        origins = [item.strip() for item in raw.split(",") if item.strip()]
        self.assertEqual(len(origins), 2)
        self.assertNotIn("*", origins)


if __name__ == "__main__":
    unittest.main()
