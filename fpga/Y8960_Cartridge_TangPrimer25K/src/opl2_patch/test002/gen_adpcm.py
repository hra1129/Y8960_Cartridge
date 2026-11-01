# Generates adpcm.hex (Y8950 ADPCM data) and ref.txt (decoded reference
# values, same algorithm as MAME ymdeltat / openMSX Y8950Adpcm) for tb.sv.
import math
import random

N = 1200
F1 = [1, 3, 5, 7, 9, 11, 13, 15, -1, -3, -5, -7, -9, -11, -13, -15]
F2 = [57, 57, 57, 57, 77, 102, 128, 153] * 2


def tdiv(a, b):
    return int(a / b)


def decode(acc, step, n):
    acc = max(-32768, min(32767, acc + tdiv(F1[n] * step, 8)))
    step = max(127, min(24576, tdiv(step * F2[n], 64)))
    return acc, step


random.seed(1)
signal = []
for i in range(N):
    t = i / 16000.0
    tone = math.sin(2 * math.pi * 80 * t * (1 + 2 * math.exp(-t * 30))) * 0.8
    noise = random.gauss(0, 0.35) * math.exp(-t * 25)
    signal.append(int(max(-32768, min(32767, (tone + noise) * math.exp(-t * 8) * 26000))))

acc, step, nibbles = 0, 127, []
for x in signal:
    d = x - acc
    n = (8 if d < 0 else 0) | min(7, (abs(d) * 4) // step)
    nibbles.append(n)
    acc, step = decode(acc, step, n)

data = [(nibbles[i] << 4) | nibbles[i + 1] for i in range(0, len(nibbles), 2)]
assert len(data) % 4 == 0

acc, step, ref = 0, 127, []
for b in data:
    for n in (b >> 4, b & 15):
        acc, step = decode(acc, step, n)
        ref.append(acc)

with open('adpcm.hex', 'w', newline='\n') as f:
    f.write(''.join(f'{b:02X}\n' for b in data))
with open('ref.txt', 'w', newline='\n') as f:
    f.write(''.join(f'{v}\n' for v in ref))
