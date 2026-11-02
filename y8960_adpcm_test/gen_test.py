# Y8960/Y8950 ADPCM test sample generator.
# Encoder/decoder algorithm identical to the repo's test002/gen_adpcm.py
# (MAME ymdeltat / openMSX Y8950Adpcm compatible). Nibbles packed high first.
import math
import numpy as np
from scipy.io import wavfile

F1 = [1, 3, 5, 7, 9, 11, 13, 15, -1, -3, -5, -7, -9, -11, -13, -15]
F2 = [57, 57, 57, 57, 77, 102, 128, 153] * 2
FS = 497159027 // 10000 * 32768 // 65536  # not used; exact below
FS = 3579545 / 72 * 32768 / 65536         # DELTA-N=0x8000 -> 24857.95 Hz

def tdiv(a, b):
    return int(a / b)

def decode_step(acc, step, n):
    acc = max(-32768, min(32767, acc + tdiv(F1[n] * step, 8)))
    step = max(127, min(24576, tdiv(step * F2[n], 64)))
    return acc, step

def encode(signal):
    acc, step, nibbles = 0, 127, []
    for x in signal:
        d = int(x) - acc
        n = (8 if d < 0 else 0) | min(7, (abs(d) * 4) // step)
        nibbles.append(n)
        acc, step = decode_step(acc, step, n)
    return bytes((nibbles[i] << 4) | nibbles[i + 1] for i in range(0, len(nibbles), 2))

def decode(data):
    acc, step, out = 0, 127, []
    for b in data:
        for n in (b >> 4, b & 15):
            acc, step = decode_step(acc, step, n)
            out.append(acc)
    return np.array(out, dtype=np.int16)

def make(name, signal):
    signal = np.asarray(signal, dtype=np.float64)
    assert len(signal) % 8 == 0
    data = encode(signal)
    with open(name + ".BIN", "wb") as f:
        f.write(data)
    ref = decode(data)
    wavfile.write(name + "_ref.wav", int(round(FS)), ref)
    print(f"{name}: {len(signal)} samples, {len(data)} bytes, stop_reg={(len(data)//4 - 1)} (0x{len(data)//4 - 1:04X})")
    return signal, ref

n1 = 24856            # ~1.0 s, multiple of 8 samples (=4 bytes)
t = np.arange(n1) / FS
# 1) silence (encode a zero signal; decoder dithers around 0)
sig, ref = make("SILENT", np.zeros(n1))
print("   silence ref: max|.| =", int(np.abs(ref).max()), " rms =", float(np.sqrt((ref.astype(np.float64)**2).mean())))
# 2) 1 kHz sine, amplitude 16000 (~-6 dBFS)
sine = np.round(16000 * np.sin(2 * np.pi * 1000 * t)).astype(np.int64)
sig, ref = make("SINE1K", sine)
# SNR of reference decode vs ideal sine (least-squares fit of amplitude/phase)
A = np.stack([np.sin(2*np.pi*1000*t), np.cos(2*np.pi*1000*t)], axis=1)
coef, *_ = np.linalg.lstsq(A, ref.astype(np.float64), rcond=None)
fit = A @ coef
err = ref.astype(np.float64) - fit
print(f"   sine ref decode SNR vs ideal: {10*np.log10((fit**2).mean()/(err**2).mean()):.1f} dB, fitted amplitude {np.hypot(*coef):.0f}")
# 3) log sweep 100 Hz -> 10 kHz, ~2 s, amplitude 16000
n2 = 49712
t2 = np.arange(n2) / FS
T = n2 / FS
f0, f1 = 100.0, 10000.0
phase = 2 * np.pi * f0 * T / np.log(f1/f0) * (np.exp(t2 / T * np.log(f1/f0)) - 1)
sweep = np.round(16000 * np.sin(phase)).astype(np.int64)
sig, ref = make("SWEEP", sweep)
print("   sweep ref written")
