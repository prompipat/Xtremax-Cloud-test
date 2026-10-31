"""Exercise retry/secret/SQL behavior with fake clients, never real AWS or MySQL."""

import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("initializer", ROOT / "modules/initialization/lambda/handler.py")
INITIALIZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INITIALIZER)


class MissingSecret(Exception):
    pass


class FakeSecrets:
    class exceptions:
        ResourceNotFoundException = MissingSecret

    def __init__(self, events, existing=None):
        self.events = events
        self.application = existing
        self.puts = []

    def get_secret_value(self, SecretId):
        self.events.append("read:" + SecretId)
        if SecretId == "master":
            return {"SecretString": json.dumps({"username": "wpadmin", "password": "FAKE_MASTER_PASSWORD"})}
        if self.application is None:
            raise MissingSecret()
        return {"SecretString": json.dumps(self.application)}

    def put_secret_value(self, SecretId, SecretString):
        self.events.append("write:" + SecretId)
        self.application = json.loads(SecretString)
        self.puts.append(self.application.copy())


class InitializerTests(unittest.TestCase):
    def setup_case(self, existing=None, lock_result=1):
        events = []
        client = FakeSecrets(events, existing)
        cursor = Mock()
        cursor.__enter__ = Mock(return_value=cursor)
        cursor.__exit__ = Mock(return_value=False)
        cursor.fetchone.return_value = (lock_result,)
        cursor.execute.side_effect = lambda query, *args: events.append(query)
        connection = Mock()
        connection.cursor.return_value = cursor
        connect = Mock(return_value=connection)
        return events, client, cursor, connection, connect

    @patch.object(INITIALIZER.ssl, "create_default_context")
    def test_new_credentials_created_after_lock_and_only_schema_granted(self, tls):
        events, client, cursor, connection, connect = self.setup_case()
        result = INITIALIZER.initialize(client, connect, {"MASTER_SECRET_ARN": "master", "APPLICATION_SECRET_ARN": "app", "DB_ADDRESS": "db.example"})
        self.assertEqual(result, {"ready": True})
        self.assertLess(events.index("SELECT GET_LOCK('xtremax_database_init', 30)"), events.index("read:app"))
        self.assertLess(events.index("write:app"), events.index("CREATE USER IF NOT EXISTS 'wordpress'@'%%' IDENTIFIED BY %s REQUIRE SSL"))
        self.assertEqual(len(client.application["salts"]), 8)
        self.assertGreaterEqual(len(client.application["password"]), 40)
        self.assertIn("GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wordpress'@'%'", events)
        self.assertNotIn("FAKE_MASTER_PASSWORD", repr(cursor.execute.call_args_list))
        self.assertEqual(connect.call_args.kwargs["ssl"], tls.return_value)
        connection.close.assert_called_once()

    @patch.object(INITIALIZER.ssl, "create_default_context")
    def test_retry_reuses_existing_application_password(self, tls):
        existing = {"username": "wordpress", "password": "FAKE_STABLE_PASSWORD"}
        events, client, cursor, connection, connect = self.setup_case(existing)
        INITIALIZER.initialize(client, connect, {"MASTER_SECRET_ARN": "master", "APPLICATION_SECRET_ARN": "app", "DB_ADDRESS": "db.example"})
        self.assertEqual(client.puts, [])
        password_calls = [call for call in cursor.execute.call_args_list if len(call.args) > 1]
        self.assertTrue(password_calls)
        self.assertTrue(all(call.args[1] == ("FAKE_STABLE_PASSWORD",) for call in password_calls))

    @patch.object(INITIALIZER.ssl, "create_default_context")
    def test_failed_lock_does_not_read_or_change_application_secret(self, tls):
        events, client, cursor, connection, connect = self.setup_case(lock_result=0)
        with self.assertRaisesRegex(RuntimeError, "lock unavailable"):
            INITIALIZER.initialize(client, connect, {"MASTER_SECRET_ARN": "master", "APPLICATION_SECRET_ARN": "app", "DB_ADDRESS": "db.example"})
        self.assertNotIn("read:app", events)
        self.assertEqual(client.puts, [])
        connection.close.assert_called_once()

    @patch.object(INITIALIZER.ssl, "create_default_context")
    def test_sql_failure_releases_lock_and_retains_retry_credentials(self, tls):
        events, client, cursor, connection, connect = self.setup_case()
        def execute(query, *args):
            events.append(query)
            if query.startswith("ALTER USER"):
                raise RuntimeError("simulated interruption")
        cursor.execute.side_effect = execute
        with self.assertRaisesRegex(RuntimeError, "simulated interruption"):
            INITIALIZER.initialize(client, connect, {"MASTER_SECRET_ARN": "master", "APPLICATION_SECRET_ARN": "app", "DB_ADDRESS": "db.example"})
        self.assertIsNotNone(client.application)
        self.assertIn("SELECT RELEASE_LOCK('xtremax_database_init')", events)
        connection.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
