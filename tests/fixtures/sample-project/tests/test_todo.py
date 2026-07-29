import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
import todo


class TestTodo(unittest.TestCase):
    def test_add(self):
        self.assertEqual(todo.add([], "buy milk"), ["buy milk"])

    def test_add_empty_rejected(self):
        with self.assertRaises(ValueError):
            todo.add([], "  ")

    def test_render(self):
        self.assertEqual(todo.render(["a", "b"]), "1. a\n2. b")


if __name__ == "__main__":
    unittest.main()
