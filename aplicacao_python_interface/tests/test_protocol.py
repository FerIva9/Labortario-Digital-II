import unittest
from protocol import Decoder, Event, parse_line


class ProtocolTests(unittest.TestCase):
    def test_all_codes(self):
        for h in range(4):
            for p in range(6):
                self.assertEqual(parse_line(f'H{h},P{p}\n'.encode()), Event(h, p))

    def test_fragmentation(self):
        d = Decoder()
        self.assertEqual(d.feed(b'H1,'), [])
        self.assertEqual(d.feed(b'P2\nH0,P5\nH3'), [Event(1, 2), Event(0, 5)])
        self.assertEqual(d.feed(b',P0\r\n'), [Event(3, 0)])

    def test_invalid(self):
        for frame in [b'H4,P0\n', b'H0,P6\n', b'H0,P0', b'H00,P0\n', b'\xff\n', b'\n']:
            with self.assertRaises(ValueError):
                parse_line(frame)

    def test_noise_recovery(self):
        results = Decoder().feed(b'noise\nH2,P4\n')
        self.assertIsInstance(results[0], ValueError)
        self.assertEqual(results[1], Event(2, 4))

    def test_overflow_recovery(self):
        d = Decoder()
        results = d.feed(b'x' * 10000 + b'H0,P0\nH1,P1\n')
        self.assertEqual(len(results), 2)
        self.assertIsInstance(results[0], ValueError)
        self.assertEqual(results[1], Event(1, 1))
        self.assertEqual(len(d.buffer), 0)

    def test_repetitions(self):
        self.assertEqual(Decoder().feed(b'H0,P2\nH0,P2\n'), [Event(0, 2), Event(0, 2)])
