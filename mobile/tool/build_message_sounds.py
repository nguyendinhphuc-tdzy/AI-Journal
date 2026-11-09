# Usage (any Python 3, standard library only):
#   python tool/build_message_sounds.py assets/sounds
"""Synthesise the two message sounds (no recording, nothing to license):

- message_in.wav: a soft two-note bell (G5 then D6, a fifth apart), each
  note a sine with a quiet octave and a fast-attack, slow-decay envelope,
  about 0.55 s. Played when a friend's message arrives.
- message_out.wav: a short rising "pop" (a 0.09 s sine sweep, 660 to 990 Hz),
  played when the user's own message goes.

Both mono 16-bit 44.1 kHz WAV, peaks at about -8 dBFS so they sit under the
interface's other sounds. Credits: assets/sounds/CREDITS.md.
"""
import math
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
PEAK = 0.4  # about -8 dBFS


def bell(freq, start, length, total):
    """A sine bell at [freq] from [start] s, [length] s long."""
    out = [0.0] * total
    first = int(start * RATE)
    for i in range(int(length * RATE)):
        t = i / RATE
        # 6 ms attack, then an exponential decay.
        env = min(1.0, t / 0.006) * math.exp(-t * 7.0)
        tone = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)
        if first + i < total:
            out[first + i] += env * tone
    return out


def message_in():
    total = int(0.62 * RATE)
    a = bell(783.99, 0.0, 0.5, total)   # G5
    b = bell(1174.66, 0.11, 0.5, total)  # D6
    return [x + 0.85 * y for x, y in zip(a, b)]


def message_out():
    length = 0.09
    samples = []
    phase = 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        freq = 660 + (990 - 660) * (t / length)
        phase += 2 * math.pi * freq / RATE
        env = math.sin(math.pi * t / length) ** 2
        samples.append(env * math.sin(phase))
    return samples


def write(path, samples):
    top = max(abs(s) for s in samples) or 1.0
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / top * PEAK)) * 32767))
        for s in samples)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


if __name__ == "__main__":
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/sounds")
    write(folder / "message_in.wav", message_in())
    write(folder / "message_out.wav", message_out())
