"""The proof must come from the expected thread's actual assistant message."""
import json
import unittest
from codex_probe import parse_codex_response


def event(obj):
    return json.dumps(obj)


class ProofParserTest(unittest.TestCase):
    def test_correct_message(self):
        stdout = '\n'.join([event({'type':'thread.started','thread_id':'A'}),
                            event({'type':'item.completed','item':{'type':'agent_message','text':'POC_ALERTE_ABC'}})])
        self.assertEqual(parse_codex_response(stdout, 'A'), 'POC_ALERTE_ABC')

    def test_marker_in_user_echo_is_not_assistant_output(self):
        stdout = '\n'.join([event({'type':'thread.started','thread_id':'A'}),
                            event({'type':'item.completed','item':{'type':'user_message','text':'POC_ALERTE_ABC'}}),
                            event({'type':'item.completed','item':{'type':'agent_message','text':'AUCUNE'}})])
        self.assertEqual(parse_codex_response(stdout, 'A'), 'AUCUNE')

    def test_wrong_thread_is_rejected(self):
        stdout = '\n'.join([event({'type':'thread.started','thread_id':'B'}),
                            event({'type':'item.completed','item':{'type':'agent_message','text':'POC_ALERTE_ABC'}})])
        with self.assertRaises(ValueError):
            parse_codex_response(stdout, 'A')

    def test_echo_only_is_rejected(self):
        stdout = '\n'.join([event({'type':'thread.started','thread_id':'A'}),
                            event({'type':'item.completed','item':{'type':'user_message','text':'POC_ALERTE_ABC'}})])
        with self.assertRaises(ValueError):
            parse_codex_response(stdout, 'A')


if __name__ == '__main__':
    unittest.main()
