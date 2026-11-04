"""Black-box checks of the real ELF executable; Python is not used by the game."""
from collections import deque
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def play(commands):
    result = subprocess.run([str(ROOT / 'build/maze')], input=commands,
                            capture_output=True, timeout=5)
    if result.returncode != 0:
        raise AssertionError(f'Game exited with {result.returncode}: {result.stderr!r}')
    return result.stdout.decode('ascii')


def solve():
    # Find a route from the actual rendered map, not a hard-coded solution.
    rows = re.findall(r'^#[# @S]+#$', play(b''), re.MULTILINE)
    assert len(rows) == 11 and all(len(row) == 21 for row in rows)
    start = next((x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == '@')
    queue = deque([(start, '')])
    seen = {start}
    while queue:
        (x, y), route = queue.popleft()
        if rows[y][x] == 'S':
            return route
        for command, dx, dy in [('z', 0, -1), ('s', 0, 1), ('q', -1, 0), ('d', 1, 0)]:
            nx, ny = x + dx, y + dy
            if (0 <= ny < len(rows) and 0 <= nx < len(rows[ny]) and
                    rows[ny][nx] != '#' and (nx, ny) not in seen):
                seen.add((nx, ny))
                queue.append(((nx, ny), route + command))
    raise AssertionError('The exit is unreachable')


class GameTests(unittest.TestCase):
    def test_quit_and_eof(self):
        for commands in (b'', b'x', b'x\n', b'X\r\n'):
            text = play(commands)
            self.assertIn('Moves: 0', text)
            self.assertIn('Thanks for playing!', text)

    def test_walls_do_not_count(self):
        text = play(b'z\nq\nd\nx\n')
        self.assertEqual(text.count('Blocked by a wall.'), 2)
        self.assertEqual(re.findall(r'Moves: (\d+)', text), ['0', '1'])

    def test_invalid_lines_do_not_execute_moves(self):
        text = play(b'\ndd\n?\n' + b'd' * 10000 + b'\n\x00\nD\r\nx\n')
        self.assertEqual(text.count('Use one of'), 5)
        self.assertEqual(re.findall(r'Moves: (\d+)', text), ['0', '1'])

    def test_restart_resets_position_and_count(self):
        text = play(b'd\nd\nr\nq\nx\n')
        self.assertEqual(re.findall(r'Moves: (\d+)', text), ['0', '1', '2', '0'])
        self.assertIn('New game.', text)
        self.assertIn('Blocked by a wall.', text)

    def test_complete_game_and_replay(self):
        route = solve()
        self.assertGreater(len(route), 9)  # Exercise decimal counters beyond one digit.
        moves = ''.join(c + '\n' for c in route).encode()
        text = play(moves + b'd\nr\n' + moves + b'x\n')
        self.assertEqual(text.count('You escaped!'), 2)
        self.assertEqual(re.findall(r'Final moves: (\d+)', text), [str(len(route))] * 2)

    def test_input_error_exits_nonzero(self):
        # A write-only stdin descriptor makes read fail with EBADF.
        with open('/dev/null', 'wb') as invalid_input:
            result = subprocess.run([str(ROOT/'build/maze')], stdin=invalid_input,
                                    stdout=subprocess.DEVNULL, timeout=5)
        self.assertEqual(result.returncode, 1)


if __name__ == '__main__':
    unittest.main()
