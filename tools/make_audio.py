#!/usr/bin/env python3
"""Genererer Astro Balls lydbank.

Ingen samples, ingen afhaengigheder. Alt syntetiseres her, saa lydene kan
justeres ved at aendre et tal og koere scriptet igen.

Designdokumentets afsnit 12: lydene er toerre og korte i sig selv.
Rumklangen laegges paa i Godot via en bus, saa alt sidder i det samme
kammer i stedet for at have hver sin bagte klang.

    python3 tools/make_audio.py
"""

import array
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


# --- byggeklodser ------------------------------------------------------

def frames(seconds):
    return int(RATE * seconds)


def silence(seconds):
    return [0.0] * frames(seconds)


def add(buf, offset_s, other, gain=1.0):
    start = frames(offset_s)
    need = start + len(other)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(other):
        buf[start + i] += v * gain
    return buf


def env_exp(n, tau, attack_s=0.001):
    """Hurtig attack, eksponentielt fald. Det er sådan et slag lyder."""
    out = []
    a = max(1, frames(attack_s))
    for i in range(n):
        e = math.exp(-i / (RATE * tau))
        if i < a:
            e *= i / a
        out.append(e)
    return out


def osc(seconds, f0, f1=None, shape="sine", phase=0.0):
    n = frames(seconds)
    f1 = f0 if f1 is None else f1
    out = []
    ph = phase
    for i in range(n):
        t = i / max(n - 1, 1)
        # Logaritmisk sweep foeles rigtigt for oeret.
        f = f0 * ((f1 / f0) ** t) if f0 > 0 and f1 > 0 else f0
        ph += 2.0 * math.pi * f / RATE
        if shape == "sine":
            v = math.sin(ph)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "square":
            v = 1.0 if math.sin(ph) >= 0 else -1.0
        elif shape == "saw":
            v = 2.0 * ((ph / (2.0 * math.pi)) % 1.0) - 1.0
        else:
            v = math.sin(ph)
        out.append(v)
    return out


def noise(seconds, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(frames(seconds))]


def lowpass(sig, cutoff):
    """Enkel en-pols. Nok til at tage kanten af støj."""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in sig:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    low = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, low)]


def sweep_lowpass(sig, c0, c1):
    n = len(sig)
    y = 0.0
    out = []
    for i, x in enumerate(sig):
        t = i / max(n - 1, 1)
        c = c0 * ((c1 / c0) ** t)
        a = 1.0 - math.exp(-2.0 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def apply_env(sig, env):
    return [s * e for s, e in zip(sig, env)]


def hit(seconds, freq, tau, shape="tri", bend=1.0):
    n = frames(seconds)
    body = osc(seconds, freq, freq * bend, shape)
    return apply_env(body, env_exp(n, tau))


def click(seconds, rng, cutoff=5000.0, tau=0.004):
    n = frames(seconds)
    return apply_env(lowpass(noise(seconds, rng), cutoff), env_exp(n, tau))


def note_hz(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))


def write(name, buf, peak=0.85, fade_out_s=0.004):
    if not buf:
        return
    # Fald til nul til sidst, ellers klikker afspilningen.
    fade = frames(fade_out_s)
    for i in range(min(fade, len(buf))):
        buf[len(buf) - 1 - i] *= i / max(fade, 1)

    hi = max(abs(v) for v in buf) or 1.0
    scale = peak / hi
    data = array.array("h", (int(max(-1.0, min(1.0, v * scale)) * 32767) for v in buf))

    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print("  %-16s %5.2f s" % (name + ".wav", len(buf) / RATE))


# --- lydene ------------------------------------------------------------

def make_brick(rng):
    """Klodsen der gaar i stykker. Toer, kort, med en tone der kan
    transponeres op med komboen i spillet."""
    buf = silence(0.14)
    add(buf, 0.0, hit(0.13, 640.0, 0.028, "tri", 0.88), 0.85)
    add(buf, 0.0, hit(0.06, 1280.0, 0.010, "sine"), 0.25)
    add(buf, 0.0, click(0.02, rng, 6000.0, 0.003), 0.5)
    write("brick", buf)


def make_brick_hard(rng):
    """Haerdet tager skade: metallisk klik, ingen splinter i lyden."""
    buf = silence(0.16)
    for f, tau, g in ((1180.0, 0.020, 0.6), (1837.0, 0.014, 0.4), (2670.0, 0.009, 0.3)):
        add(buf, 0.0, hit(0.15, f, tau, "sine"), g)
    add(buf, 0.0, click(0.02, rng, 8000.0, 0.002), 0.55)
    write("brick_hard", buf)


def make_blast(rng):
    """Spraengklodsen. Dyb, kort, med et sug nedad."""
    buf = silence(0.7)
    add(buf, 0.0, apply_env(osc(0.5, 150.0, 38.0, "sine"), env_exp(frames(0.5), 0.16)), 1.0)
    body = sweep_lowpass(noise(0.5, rng), 3200.0, 180.0)
    add(buf, 0.0, apply_env(body, env_exp(frames(0.5), 0.13)), 0.75)
    add(buf, 0.0, click(0.03, rng, 9000.0, 0.004), 0.6)
    write("blast", buf)


def make_glass(rng):
    """Is i vakuum: mange smaa skaar, hoej klirren, laenge om at falde."""
    buf = silence(0.5)
    for i in range(11):
        at = rng.uniform(0.0, 0.16)
        f = rng.uniform(2400.0, 6200.0)
        dur = rng.uniform(0.05, 0.16)
        add(buf, at, hit(dur, f, rng.uniform(0.02, 0.05), "sine"), rng.uniform(0.2, 0.5))
    shimmer = highpass(noise(0.28, rng), 4000.0)
    add(buf, 0.0, apply_env(shimmer, env_exp(frames(0.28), 0.07)), 0.3)
    write("glass", buf)


def make_paddle(rng):
    """Dybt klik fra skjoldet. Det skal kunne maerkes i brystet."""
    buf = silence(0.16)
    add(buf, 0.0, hit(0.15, 165.0, 0.045, "sine", 0.72), 1.0)
    add(buf, 0.0, hit(0.07, 330.0, 0.018, "tri"), 0.3)
    add(buf, 0.0, click(0.015, rng, 3000.0, 0.003), 0.35)
    write("paddle", buf)


def make_wall(rng):
    """Feltet bliver ramt. Toert klik, naesten ingenting."""
    buf = silence(0.08)
    band = highpass(lowpass(noise(0.07, rng), 2600.0), 900.0)
    add(buf, 0.0, apply_env(band, env_exp(frames(0.07), 0.012)), 0.9)
    add(buf, 0.0, hit(0.05, 1400.0, 0.008, "sine"), 0.25)
    write("wall", buf)


def make_powerup_good():
    """Kapslen imploderer. Tre toner opad, ren dur."""
    buf = silence(0.42)
    for i, semi in enumerate((3, 7, 12)):
        add(buf, i * 0.055, hit(0.24, note_hz(semi), 0.07, "tri"), 0.7 - i * 0.05)
        add(buf, i * 0.055, hit(0.16, note_hz(semi + 12), 0.04, "sine"), 0.18)
    write("powerup_good", buf)


def make_powerup_bad():
    """Den daarlige. To toner nedad, en anelse ude af stemning."""
    buf = silence(0.42)
    add(buf, 0.0, hit(0.22, note_hz(-2), 0.08, "square"), 0.4)
    add(buf, 0.0, hit(0.22, note_hz(-2) * 1.012, 0.08, "square"), 0.3)
    add(buf, 0.13, hit(0.26, note_hz(-8), 0.10, "square"), 0.4)
    add(buf, 0.13, hit(0.26, note_hz(-8) * 1.012, 0.10, "square"), 0.3)
    write("powerup_bad", buf)


def make_laser(rng):
    """To straaler op. Kort chirp nedad i tonehoejde."""
    buf = silence(0.18)
    add(buf, 0.0, apply_env(osc(0.13, 2100.0, 420.0, "saw"), env_exp(frames(0.13), 0.035)), 0.6)
    add(buf, 0.0, apply_env(osc(0.13, 1050.0, 210.0, "square"), env_exp(frames(0.13), 0.03)), 0.25)
    add(buf, 0.0, click(0.02, rng, 7000.0, 0.003), 0.3)
    write("laser", buf)


def make_life_lost(rng):
    """Kometen splintrer og suges nedad. Alt taber hoejde."""
    buf = silence(1.1)
    add(buf, 0.0, apply_env(osc(0.85, 480.0, 55.0, "sine"), env_exp(frames(0.85), 0.34)), 0.9)
    add(buf, 0.0, apply_env(osc(0.85, 240.0, 27.5, "tri"), env_exp(frames(0.85), 0.30)), 0.35)
    tail = sweep_lowpass(noise(0.8, rng), 2400.0, 220.0)
    add(buf, 0.02, apply_env(tail, env_exp(frames(0.8), 0.26)), 0.3)
    write("life_lost", buf)


def make_level_clear():
    """Feltet er ryddet. Op ad en dur-akkord og bliv der."""
    buf = silence(1.5)
    for i, semi in enumerate((0, 4, 7, 12, 16)):
        add(buf, i * 0.075, hit(0.5, note_hz(semi), 0.20, "tri"), 0.5)
        add(buf, i * 0.075, hit(0.4, note_hz(semi + 12), 0.14, "sine"), 0.16)
    for semi in (0, 7, 16):
        add(buf, 0.42, hit(1.0, note_hz(semi), 0.42, "tri"), 0.28)
    write("level_clear", buf)


def make_game_over():
    """Mol, nedad, langsomt. Ingen straf, bare tyngde."""
    buf = silence(2.0)
    for i, semi in enumerate((7, 3, 0, -5)):
        add(buf, i * 0.20, hit(1.1, note_hz(semi), 0.34, "tri"), 0.45)
        add(buf, i * 0.20, hit(0.9, note_hz(semi - 12), 0.30, "sine"), 0.30)
    for semi in (-5, -1, 2):
        add(buf, 0.78, hit(1.2, note_hz(semi), 0.5, "tri"), 0.22)
    write("game_over", buf)


def make_combo():
    """Kombo 5, 10, 20. En kvint der glimter."""
    buf = silence(0.7)
    for i, semi in enumerate((12, 19, 24)):
        add(buf, i * 0.045, hit(0.5, note_hz(semi), 0.16, "sine"), 0.4 - i * 0.08)
    write("combo", buf)


def make_ui():
    buf = silence(0.09)
    add(buf, 0.0, hit(0.08, note_hz(7), 0.022, "tri"), 0.55)
    write("ui_move", buf)

    buf = silence(0.24)
    add(buf, 0.0, hit(0.12, note_hz(7), 0.035, "tri"), 0.55)
    add(buf, 0.06, hit(0.18, note_hz(14), 0.06, "tri"), 0.5)
    write("ui_select", buf)

    buf = silence(0.26)
    add(buf, 0.0, hit(0.20, note_hz(2), 0.06, "tri"), 0.5)
    add(buf, 0.07, hit(0.20, note_hz(-5), 0.07, "tri"), 0.45)
    write("ui_back", buf)


def make_launch(rng):
    """Bolden slippes. Et lille skub."""
    buf = silence(0.22)
    add(buf, 0.0, apply_env(osc(0.18, 180.0, 700.0, "tri"), env_exp(frames(0.18), 0.06)), 0.55)
    add(buf, 0.0, click(0.02, rng, 6000.0, 0.004), 0.3)
    write("launch", buf)


def make_drone():
    """Under spil er der ingen musik, kun en dyb, naesten uhoerlig drone.
    Alle frekvenser gaar op i loeklaengden, ellers klikker loekken."""
    loop_s = 8.0
    n = frames(loop_s)
    buf = [0.0] * n
    # 440, 441, 660 og 880 hele svingninger paa 8 sekunder.
    for cycles, gain in ((440, 0.55), (441, 0.5), (660, 0.16), (880, 0.07)):
        f = cycles / loop_s
        for i in range(n):
            buf[i] += gain * math.sin(2.0 * math.pi * f * i / RATE)
    # Langsom aandedraet, ogsaa med hel periode.
    for i in range(n):
        breathe = 0.82 + 0.18 * math.sin(2.0 * math.pi * (1.0 / loop_s) * i / RATE)
        buf[i] *= breathe
    write("drone", buf, peak=0.6, fade_out_s=0.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(20260824)
    print("Genererer lydbank i %s" % OUT)
    make_brick(rng)
    make_brick_hard(rng)
    make_blast(rng)
    make_glass(rng)
    make_paddle(rng)
    make_wall(rng)
    make_powerup_good()
    make_powerup_bad()
    make_laser(rng)
    make_life_lost(rng)
    make_level_clear()
    make_game_over()
    make_combo()
    make_ui()
    make_launch(rng)
    make_drone()
    print("Faerdig.")


if __name__ == "__main__":
    main()
