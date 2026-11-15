#!/usr/bin/env python3
import importlib.util
import itertools
from pathlib import Path
import sys
import tempfile
import types
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kensington_mouse', ROOT / 'scripts/kensington-mouse.py')
mouse = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mouse
SPEC.loader.exec_module(mouse)

BUTTONS = {'top_left': 275, 'top_right': 276, 'bottom_left': 272, 'bottom_right': 273}
PAIRS = {
    ('top_left', 'bottom_left'): 'workspace_previous',
    ('top_right', 'bottom_right'): 'workspace_next',
    ('top_left', 'top_right'): 'voice_toggle',
    ('bottom_left', 'bottom_right'): 'middle_click',
    ('top_left', 'bottom_right'): 'enter',
    ('top_right', 'bottom_left'): 'escape',
}


class ChordTests(unittest.TestCase):
    def setUp(self):
        self.engine = mouse.ChordEngine(BUTTONS, hold_ms=120)

    def event(self, button, value, now=0):
        return self.engine.feed(1, BUTTONS[button], value, now)

    def test_bottom_taps_are_clicks_without_waiting_for_timer(self):
        for name, code in [('bottom_left', 272), ('bottom_right', 273)]:
            with self.subTest(name=name):
                self.assertEqual(self.event(name, 1), [])
                self.assertEqual(self.event(name, 0, .04), [mouse.Emit(1, code, 1), mouse.Emit(1, code, 0)])

    def test_top_taps_dispatch_focus_only_on_release(self):
        for name, action in [('top_left', 'focus_left'), ('top_right', 'focus_right')]:
            self.assertEqual(self.event(name, 1), [])
            self.assertEqual(self.engine.tick(1), [])
            self.assertEqual(self.event(name, 0, 1.01), [mouse.Invoke(action)])

    def test_each_pair_ignores_press_and_release_order(self):
        for pair, action in PAIRS.items():
            for press in itertools.permutations(pair):
                for release in itertools.permutations(pair):
                    with self.subTest(pair=pair, press=press, release=release):
                        self.setUp()
                        effects = self.event(press[0], 1)
                        effects += self.event(press[1], 1, .03)
                        effects += self.engine.tick(1)
                        effects += self.event(release[0], 0, 1.01)
                        self.assertEqual(effects, [])
                        self.assertEqual(self.event(release[1], 0, 1.02), [mouse.Invoke(action)])
                        self.assertEqual(self.engine.tick(3), [])

    def test_three_and_four_button_gestures_are_cancelled(self):
        for count in (3, 4):
            for names in itertools.combinations(BUTTONS, count):
                for press in itertools.permutations(names):
                    for release in (press, press[::-1]):
                        self.setUp()
                        effects = []
                        for index, name in enumerate(press):
                            effects += self.event(name, 1, index * .01)
                        effects += self.engine.tick(1)
                        for index, name in enumerate(release):
                            effects += self.event(name, 0, 1.01 + index * .01)
                        self.assertEqual(effects, [], (press, release))
                        self.assertEqual(self.event('top_left', 1, 2), [])
                        self.assertEqual(self.event('top_left', 0, 2.04), [mouse.Invoke('focus_left')])

    def test_duplicate_down_repeat_and_stray_up_do_not_fire_actions(self):
        self.assertEqual(self.event('top_left', 0), [])
        self.assertEqual(self.event('top_left', 2), [])
        self.assertEqual(self.event('top_left', 1), [])
        self.assertEqual(self.event('top_left', 1, .01), [])
        self.assertEqual(self.event('top_left', 2, .02), [])
        self.assertEqual(self.event('top_left', 0, .03), [mouse.Invoke('focus_left')])
        self.assertEqual(self.event('top_left', 0, .04), [])

    def test_lower_hold_becomes_drag_and_releases_once(self):
        self.assertEqual(self.event('bottom_left', 1), [])
        self.assertEqual(self.engine.tick(.119), [])
        self.assertEqual(self.engine.tick(.121), [mouse.Emit(1, 272, 1)])
        self.assertEqual(self.engine.feed(2, 0, 12, .14), [mouse.Emit(2, 0, 12)])
        self.assertEqual(self.event('bottom_left', 0, .15), [mouse.Emit(1, 272, 0)])
        self.assertEqual(self.event('bottom_left', 0, .16), [])

    def test_motion_commits_drag_before_forwarding_movement(self):
        self.event('bottom_left', 1)
        effects = self.engine.feed(2, 0, 8, .03)
        self.assertEqual(effects, [mouse.Emit(1, 272, 1), mouse.Emit(2, 0, 8)])
        self.assertEqual(self.event('bottom_left', 0, .04), [mouse.Emit(1, 272, 0)])

    def test_lower_hold_does_not_turn_into_late_chord(self):
        self.event('bottom_left', 1)
        self.engine.tick(.13)
        self.assertEqual(self.event('top_left', 1, .14), [])
        self.assertEqual(self.event('bottom_left', 0, .15), [mouse.Emit(1, 272, 0)])
        self.assertEqual(self.event('top_left', 0, .16), [])

    def test_partial_release_then_new_press_cancels_gesture(self):
        self.event('top_left', 1)
        self.event('top_right', 1, .02)
        self.event('top_left', 0, .04)
        self.event('bottom_right', 1, .05)
        self.assertEqual(self.event('top_right', 0, .06), [])
        self.assertEqual(self.event('bottom_right', 0, .07), [])

    def test_repeated_taps_stay_two_clicks(self):
        effects = []
        for start in (0, .1):
            effects += self.event('bottom_left', 1, start)
            effects += self.event('bottom_left', 0, start + .03)
        self.assertEqual(effects, [mouse.Emit(1, 272, 1), mouse.Emit(1, 272, 0)] * 2)

    def test_relative_wheel_high_resolution_and_unknown_buttons_pass_through(self):
        for event in [(2, 0, 4), (2, 1, -3), (2, 8, -1), (2, 11, -120), (2, 6, 1), (2, 12, 120), (1, 274, 1), (1, 274, 0)]:
            self.assertEqual(self.engine.feed(*event, now=0), [mouse.Emit(*event)])

    def test_reset_releases_drag_without_click_or_action(self):
        self.event('bottom_left', 1)
        self.engine.tick(.13)
        self.assertEqual(self.engine.reset(), [mouse.Emit(1, 272, 0)])
        self.assertEqual(self.engine.reset(), [])
        self.assertEqual(self.event('bottom_left', 0, .15), [])

    def test_reset_discards_pending_chord_and_can_start_cleanly(self):
        self.event('top_left', 1)
        self.event('bottom_right', 1, .02)
        self.assertEqual(self.engine.reset(), [])
        self.assertEqual(self.event('top_left', 0, .03), [])
        self.assertEqual(self.event('bottom_right', 0, .04), [])
        self.event('top_right', 1, .05)
        self.assertEqual(self.event('top_right', 0, .06), [mouse.Invoke('focus_right')])

    def test_invalid_button_mapping_is_rejected(self):
        with self.assertRaises(ValueError):
            mouse.ChordEngine({**BUTTONS, 'top_left': BUTTONS['top_right']})
        with self.assertRaises(ValueError):
            mouse.ChordEngine({'top_left': 275})
        with self.assertRaises(ValueError):
            mouse.ChordEngine(BUTTONS, hold_ms=-1)


class FakeDevice:
    def __init__(self):
        self.events = []

    def write(self, type, code, value):
        self.events.append((type, code, value))

    def syn(self):
        pass


class ActionWorkerTests(unittest.IsolatedAsyncioTestCase):
    async def test_click_actions_write_their_own_device(self):
        mouse_config = mouse.load_config()
        pointer, keyboard = FakeDevice(), FakeDevice()
        worker = mouse.ActionWorker(mouse_config, pointer, keyboard)
        await worker._execute('middle_click')
        await worker._execute('enter')
        await worker._execute('escape')
        self.assertEqual(pointer.events, [(1, 274, 1), (1, 274, 0)])
        self.assertEqual(keyboard.events, [(1, 28, 1), (1, 28, 0), (1, 1, 1), (1, 1, 0)])


class RemapperWriteTests(unittest.TestCase):
    def test_pointer_events_are_emitted_and_actions_are_queued(self):
        remapper = mouse.Remapper(mouse.load_config(), None)
        remapper.pointer = FakeDevice()
        queued = []
        remapper.worker = types.SimpleNamespace(submit=queued.append)
        remapper._write_effects([mouse.Emit(1, 272, 1), mouse.Invoke('focus_left')])
        self.assertEqual(remapper.pointer.events, [(1, 272, 1)])
        self.assertEqual(queued, ['focus_left'])


class ConfigTests(unittest.TestCase):
    def test_shipped_config_targets_the_slimblade_and_existing_shortcuts(self):
        mouse_config = mouse.load_config()
        self.assertEqual((mouse_config.vendor, mouse_config.product), (0x047d, 0x80d6))
        self.assertEqual(mouse_config.buttons, {'bottom_left': 272, 'bottom_right': 273,
                                                'top_left': 274, 'top_right': 275})
        self.assertEqual(mouse_config.commands['focus_left'], ['hyprctl', 'dispatch', 'movefocus', 'l'])
        self.assertEqual(mouse_config.commands['focus_right'], ['hyprctl', 'dispatch', 'movefocus', 'r'])
        self.assertEqual(mouse_config.commands['workspace_previous'], ['hyprctl', 'dispatch', 'workspace', 'e-1'])
        self.assertEqual(mouse_config.commands['workspace_next'], ['hyprctl', 'dispatch', 'workspace', 'e+1'])
        self.assertEqual(Path(mouse_config.commands['voice_toggle'][-2]).name, 'record')
        self.assertEqual(mouse_config.commands['voice_toggle'][-1], 'toggle')

    def test_config_rejects_repeated_button_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'kensington.toml'
            path.write_text(
                '[device]\nvendor = 1\nproduct = 2\n[gesture]\nhold_ms = 200\n'
                '[buttons]\ntop_left = 275\ntop_right = 275\nbottom_left = 272\nbottom_right = 273\n'
                '[commands]\nfocus_left = ["a"]\nfocus_right = ["a"]\nworkspace_previous = ["a"]\n'
                'workspace_next = ["a"]\nvoice_toggle = ["a"]\n', encoding='utf-8')
            with self.assertRaises(mouse.ConfigError):
                mouse.load_config(path)

    def test_config_requires_every_command(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'kensington.toml'
            path.write_text(
                '[device]\nvendor = 1\nproduct = 2\n[gesture]\nhold_ms = 200\n'
                '[buttons]\ntop_left = 275\ntop_right = 276\nbottom_left = 272\nbottom_right = 273\n'
                '[commands]\nfocus_left = ["a"]\n', encoding='utf-8')
            with self.assertRaises(mouse.ConfigError):
                mouse.load_config(path)


if __name__ == '__main__':
    unittest.main()
