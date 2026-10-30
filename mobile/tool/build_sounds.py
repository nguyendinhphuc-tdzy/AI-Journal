# Usage (macOS, Python with NumPy):
#   python tool/build_sounds.py <raw-dir> assets/sounds
"""Cut the app's sounds from the CC0 recordings in <raw-dir> (one mp3 per
slot) and write them to assets/sounds, mono: the short sounds as 16-bit
WAV (AAC would add its ~50 ms of priming silence to clips of 0.1-0.3 s and
need decoding on every play), the music as AAC (.m4a) to keep it small.
Sources and licences: assets/sounds/CREDITS.md.

- Pens and the eraser: the loudest distinct strokes of each recording,
  four (two for the eraser) short clips with soft edges, one played per
  typed letter.
- Page turns: the strongest turns, one per clip.
- One-shots (book, paper, pen click): the sound itself,
  silence trimmed, capped in length and faded out.
- Music: up to MUSIC_SECONDS, its end crossfaded into its start so it
  loops without a seam, at one quiet loudness (peaks kept under -3 dBFS).

Decoding and encoding use afconvert (built into macOS).
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
MUSIC_SECONDS = 90
LOOP_FADE = 3.0

raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
work = Path(tempfile.mkdtemp())


def load(name):
    """The recording as mono floats at RATE, or None when it is missing."""
    src = raw_dir / f'{name}.mp3'
    if not src.exists():
        print(f'missing {src.name}')
        return None
    wav = work / f'{name}.wav'
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', f'LEI16@{RATE}',
                    '-c', '1', str(src), str(wav)], check=True)
    with wave.open(str(wav)) as f:
        data = np.frombuffer(f.readframes(f.getnframes()), np.int16)
    return data.astype(np.float32) / 32768


def save(name, audio, music=False):
    """A short sound as out_dir/<name>.wav; music as <name>.m4a."""
    wav = (work if music else out_dir) / f'{name}.wav'
    pcm = (np.clip(audio, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(wav), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    out = wav
    if music:
        out = out_dir / f'{name}.m4a'
        subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '64000',
                        str(wav), str(out)], check=True)
    print(f'{out.name}: {len(audio) / RATE:.2f} s')


def envelope(audio, ms=10):
    """RMS per [ms] window."""
    hop = RATE * ms // 1000
    frames = len(audio) // hop
    blocks = audio[:frames * hop].reshape(frames, hop)
    return np.sqrt((blocks ** 2).mean(1) + 1e-12), hop


def fades(audio, fade_in=.005, fade_out=.04):
    audio = audio.copy()
    n_in, n_out = int(RATE * fade_in), int(RATE * fade_out)
    n_in, n_out = min(n_in, len(audio) // 2), min(n_out, len(audio) // 2)
    audio[:n_in] *= np.linspace(0, 1, n_in)
    audio[len(audio) - n_out:] *= np.linspace(1, 0, n_out)
    return audio


def peak(audio, db=-3.0):
    """Scaled so its loudest sample is at [db] dBFS."""
    top = np.abs(audio).max()
    return audio if top == 0 else audio * (10 ** (db / 20) / top)


def trim(audio, threshold_db=-45):
    env, hop = envelope(audio)
    loud = np.where(20 * np.log10(env) > threshold_db + 20 * np.log10(
        env.max()))[0]
    if len(loud) == 0:
        return audio
    start = max(0, loud[0] * hop - hop)
    end = min(len(audio), (loud[-1] + 2) * hop)
    return audio[start:end]


def events(audio, gap_ms=60, min_ms=60, rel_db=-24):
    """Spans of sound separated by quieter gaps, loudest first."""
    env, hop = envelope(audio)
    on = 20 * np.log10(env / env.max()) > rel_db
    spans, start, quiet = [], None, 0
    for i, flag in enumerate(on):
        if flag:
            start = i if start is None else start
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet * 10 >= gap_ms:
                spans.append((start, i - quiet + 1))
                start, quiet = None, 0
    if start is not None:
        spans.append((start, len(on)))
    spans = [(a, b) for a, b in spans if (b - a) * 10 >= min_ms]
    spans.sort(key=lambda s: -env[s[0]:s[1]].mean())
    return [(a * hop, b * hop) for a, b in spans]


def strokes(audio, count, length):
    """[count] clips of up to [length] s at the strongest distinct
    strokes; for a continuous recording, its loudest stretches."""
    found = events(audio)
    clips = []
    for start, end in found:
        end = min(end + int(RATE * .03), start + int(RATE * length))
        start = max(0, start - int(RATE * .01))
        clips.append(audio[start:end])
        if len(clips) == count:
            break
    if len(clips) < count:
        # Continuous scratching: the loudest windows, apart from each other.
        env, hop = envelope(audio, 50)
        window = int(length * 1000 / 50)
        score = np.convolve(env, np.ones(window), 'valid')
        taken = []
        for i in np.argsort(-score):
            if all(abs(i - t) >= window for t in taken):
                taken.append(i)
            if len(taken) + len(clips) == count:
                break
        clips += [audio[i * hop:i * hop + int(RATE * length)] for i in taken]
    return [peak(fades(c)) for c in clips[:count]]


def one_shot(audio, cap, fade_out=.15):
    clip = trim(audio)[:int(RATE * cap)]
    return peak(fades(clip, fade_out=fade_out))


def loop(audio):
    """At most MUSIC_SECONDS, end crossfaded into the start, quiet."""
    clip = trim(audio)[:int(RATE * (MUSIC_SECONDS + LOOP_FADE))]
    n = int(RATE * LOOP_FADE)
    body, tail = clip[:-n].copy(), clip[-n:]
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * ramp + tail * (1 - ramp)
    rms = np.sqrt((body ** 2).mean())
    # About -24 dBFS RMS, but never past -3 dBFS at the peaks (rain drops):
    # quieter rather than clipped.
    gain = min(10 ** (-24 / 20) / rms, 10 ** (-3 / 20) / np.abs(body).max())
    return body * gain


for pen, slot in [('pencil', 'pencil_writing'),
                  ('ballpoint', 'ballpoint_writing'),
                  ('fountain', 'fountain_pen_writing'),
                  ('marker', 'marker_writing')]:
    audio = load(slot)
    if audio is not None:
        for i, clip in enumerate(strokes(audio, 4, .28), 1):
            save(f'pen_{pen}_{i}', clip)

audio = load('eraser')
if audio is not None:
    for i, clip in enumerate(strokes(audio, 2, .4), 1):
        save(f'erase_{i}', clip)

# One turn from each recording: its strongest that lasts like a turn.
for i, name in enumerate(['page_turn', 'page_turn_2'], 1):
    audio = load(name)
    if audio is None:
        continue
    turns = events(audio, gap_ms=120, min_ms=300) or [(0, len(audio))]
    a, b = turns[0]
    save(f'page_turn_{i}',
         peak(fades(audio[a:min(b, a + int(RATE * 1.4))], fade_out=.12)))

for slot, name, cap, fade in [
    ('book_open', 'book_open', 1.5, .2),
    ('paper_rustle', 'paper', 1.2, .2),
    ('pen_click', 'pen_click', .4, .05),
]:
    audio = load(slot)
    if audio is not None:
        save(name, one_shot(audio, cap, fade))

for slot, name in [('rain_loop', 'music_rain'), ('cafe_loop', 'music_cafe'),
                   ('piano_loop', 'music_piano')]:
    audio = load(slot)
    if audio is not None:
        save(name, loop(audio), music=True)
