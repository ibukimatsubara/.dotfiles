#!/usr/bin/env python3
"""Exercise patched Pomoru in a real PTY without changing personal settings."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import sys
import tempfile
import termios
import time


def main():
    binary = Path(sys.argv[1] if len(sys.argv) > 1 else '~/.local/bin/pomoru').expanduser().resolve()
    with tempfile.TemporaryDirectory(prefix='pomoru-test-') as directory:
        root = Path(directory)
        config = root / 'config/pomoru'
        config.mkdir(parents=True)
        (config / 'config.toml').write_text(
            'work_time_mins = 0\nshort_break_mins = 0\nlong_break_mins = 0\n'
            'auto_switch_sessions = false\ntasks = []\n'
        )
        (config / 'alerts.toml').write_text('notifications_enabled = false\n')
        fake_bin = root / 'bin'
        fake_bin.mkdir()
        # Substitute only the external audio device boundary; run the real timer,
        # configuration loader, dispatcher, and status exporter.
        player = fake_bin / 'ffplay'
        player.write_text(
            '#!/usr/bin/env python3\nimport json, os, sys\n'
            'with open(os.environ["POMORU_TEST_AUDIO_LOG"], "a") as f:\n'
            '    f.write(json.dumps(sys.argv[1:]) + "\\n")\n'
        )
        player.chmod(0o755)
        audio_log = root / 'audio.jsonl'
        env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'),
                   XDG_CACHE_HOME=str(root / 'cache'), TERM='xterm-256color',
                   PATH=str(fake_bin) + os.pathsep + os.environ['PATH'],
                   POMORU_TEST_AUDIO_LOG=str(audio_log))
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 32, 120, 0, 0))
        pid = os.fork()
        if pid == 0:
            os.close(master)
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            for fd in (0, 1, 2):
                os.dup2(slave, fd)
            if slave > 2:
                os.close(slave)
            os.execve(str(binary), [str(binary)], env)
        os.close(slave)
        status_path = root / 'cache/pomoru/status.json'
        transcript = bytearray()

        def drain():
            if select.select([master], [], [], 0.02)[0]:
                try:
                    transcript.extend(os.read(master, 65536))
                except OSError:
                    pass

        def wait_for(predicate, message, timeout=5):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                drain()
                try:
                    if predicate():
                        return
                except (OSError, ValueError):
                    pass  # status writes can be transiently empty
            raise AssertionError(message + '\n' + transcript.decode(errors='replace')[-1000:])

        def audio_events():
            return [json.loads(line) for line in audio_log.read_text().splitlines()] if audio_log.exists() else []

        try:
            for count, mode in enumerate(('work', 'short-break', 'long-break'), 1):
                wait_for(lambda: json.loads(status_path.read_text())['class'] == mode,
                         'Status bar did not report ' + mode)
                os.write(master, b' ')
                wait_for(lambda: len(audio_events()) == count,
                         'Missing completion sound for ' + mode)
                expected = str(config / 'sounds/timer-complete.mp3')
                assert audio_events()[-1] == ['-nodisp', '-autoexit', '-loglevel', 'error', '-i', expected]
                # More than one second proves manual mode did not start another
                # zero-duration session and replay its completion sound.
                deadline = time.monotonic() + 1.2
                while time.monotonic() < deadline:
                    drain()
                assert len(audio_events()) == count, 'Sound repeated in manual mode'
                assert json.loads(status_path.read_text())['class'] == mode
                if count < 3:
                    os.write(master, b'\t')
            if '--warning' in sys.argv[2:]:
                # A real two-minute countdown reaches its warning after one minute.
                os.write(master, b'e2\r')
                wait_for(lambda: '02:00' in json.loads(status_path.read_text())['text'],
                         'Timer edit did not apply')
                os.write(master, b' ')
                wait_for(lambda: len(audio_events()) == 4,
                         'Missing one-minute warning playback', timeout=65)
                assert audio_events()[-1][-1] == str(config / 'sounds/warning-beep.mp3')
                os.write(master, b' ')
                deadline = time.monotonic() + 1.2
                while time.monotonic() < deadline:
                    drain()
                assert len(audio_events()) == 4, 'Warning repeated while paused'
            os.write(master, b'q')
            wait_for(lambda: not status_path.exists(), 'Status was not cleared on quit')
            _, exit_status = os.waitpid(pid, 0)
            pid = None
            assert os.waitstatus_to_exitcode(exit_status) == 0
            assert 'auto_switch_sessions = false' in (config / 'config.toml').read_text()
            assert (config / 'alerts.toml').read_text() == 'notifications_enabled = false\n'
        finally:
            if pid is not None:
                os.kill(pid, signal.SIGTERM)
                os.waitpid(pid, 0)
            os.close(master)
    print('PASS: Work, short break, long break audio, manual progression, bar JSON, and settings preservation')
    if '--warning' in sys.argv[2:]:
        print('PASS: Real countdown emits one-minute warning through the audio dispatcher')


if __name__ == '__main__':
    main()
