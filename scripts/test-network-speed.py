#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROUTE_HEADER = 'Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n'


class NetworkSpeedTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('speed', Path(__file__).with_name('network-speed.py'))
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def route(self, *rows):
        path = self.root / 'route'
        path.write_text(ROUTE_HEADER + ''.join(rows))
        return path

    def test_default_interface_uses_lowest_metric(self):
        path = self.route('wlp4s0\t00000000\t0100A8C0\t0003\t0\t0\t600\t00000000\t0\t0\t0\n',
                          'enp3s0\t00000000\t0100A8C0\t0003\t0\t0\t100\t00000000\t0\t0\t0\n',
                          'docker0\t000011AC\t00000000\t0001\t0\t0\t0\t0000FFFF\t0\t0\t0\n')
        self.assertEqual(self.mod.default_interface(path), 'enp3s0')

    def test_no_default_route(self):
        self.assertIsNone(self.mod.default_interface(self.route()))
        self.assertIsNone(self.mod.default_interface(self.root / 'missing'))

    def test_counters_read_sysfs(self):
        stats = self.root / 'wlan0' / 'statistics'
        stats.mkdir(parents=True)
        (stats / 'rx_bytes').write_text('100\n')
        (stats / 'tx_bytes').write_text('20\n')
        self.assertEqual(self.mod.counters('wlan0', self.root), (100, 20))
        self.assertIsNone(self.mod.counters('gone', self.root))

    def test_label_scales_units(self):
        result = self.mod.snapshot('wlan0', (0, 0), (1_500_000, 50_000), 1)
        self.assertEqual(result['label'], '↓12M ↑0.4M')
        result = self.mod.snapshot('wlan0', (0, 0), (250_000_000, 0), 1)
        self.assertEqual(result['label'], '↓2.0G ↑0.0M')

    def test_counter_reset_is_not_negative(self):
        self.assertEqual(self.mod.snapshot('wlan0', (900, 900), (0, 0), 1)['down_mbps'], 0)

    def test_missing_counters_are_unavailable(self):
        result = self.mod.snapshot('wlan0', None, None, 1)
        self.assertFalse(result['available'])
        self.assertEqual(result['label'], '--')

    def test_tooltip_includes_link_detail(self):
        result = self.mod.snapshot('wlan0', (0, 0), (0, 0), 1, 'home · Link 390.0 MBit/s')
        self.assertIn('home · Link 390.0 MBit/s', result['tooltip'])


if __name__ == '__main__':
    unittest.main()
