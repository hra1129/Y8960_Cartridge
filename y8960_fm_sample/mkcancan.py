# -----------------------------------------------------------------------------
#  mkcancan.py
#   Generates the song data (cancan.inc) of CANCAN.COM:
#   J.Offenbach "Orphee aux enfers" - Galop infernal (Can-can), arranged for
#   all the sound chips of the Y8960 Cartridge
#   (OPM, OPL2, OPLL, SCC, SSG, ADPCM).
#
#   Usage: python mkcancan.py          -> writes cancan.inc
# -----------------------------------------------------------------------------
import math
import os
import re
import random

HERE = os.path.dirname(os.path.abspath(__file__))
UNIT = 64				# ticks per whole note (16th = 4 ticks)
BAR = UNIT // 2			# 2/4

CLOCK = 3579545.0
FM_FS = CLOCK / 72.0
SSG_CLOCK = CLOCK / 2.0

# hw channel numbers
OPM, OPL2, OPLL, SCC, SSG, ADPCM, COND = 0x00, 0x08, 0x20, 0x30, 0x40, 0x50, 0xFF

# OPM RL bits (reg 20h): bit7 = R, bit6 = L
OPM_L, OPM_C, OPM_R = 0x40, 0xC0, 0x80

# -----------------------------------------------------------------------------
#  Channels: (name, hw channel, patch, pan, role)
#   role: MEL (melody), HAR (harmony), CH0-CH2 (off-beat chord voices),
#         BAS (bass), DRM (drums)
#   patch:
#     OPM  : index of opm_patches     OPL2 : index of opl_patches
#     OPLL : INST << 4 | VOL          SCC  : index of scc_patches
#     SSG  : index of psg_patches     ADPCM: -
# -----------------------------------------------------------------------------
CHANNELS = [
	("SSG",  SSG + 0, 0, 128, "MEL"),
	("SSG",  SSG + 1, 1,  80, "HAR"),
	("SSG",  SSG + 2, 2, 128, "BAS"),
	("SCC",  SCC + 0, 0, 128, "MEL"),
	("SCC",  SCC + 1, 1,  80, "HAR"),
	("SCC",  SCC + 2, 2,  48, "CH1"),
	("SCC",  SCC + 3, 3, 208, "CH2"),
	("SCC",  SCC + 4, 4, 128, "BAS"),
	("OPLL", OPLL + 0, 0x70, 128, "MEL"),		# trumpet
	("OPLL", OPLL + 1, 0x52,  80, "HAR"),		# clarinet
	("OPLL", OPLL + 2, 0x33,  48, "CH0"),		# piano
	("OPLL", OPLL + 3, 0x33, 128, "CH1"),
	("OPLL", OPLL + 4, 0x33, 208, "CH2"),
	("OPLL", OPLL + 5, 0xE0, 128, "BAS"),		# acoustic bass
	("OPL2", OPL2 + 0, 0, 128, "MEL"),		# lead
	("OPL2", OPL2 + 1, 0,  80, "HAR"),
	("OPL2", OPL2 + 2, 1,  48, "CH0"),		# harpsichord
	("OPL2", OPL2 + 3, 1, 128, "CH1"),
	("OPL2", OPL2 + 4, 1, 208, "CH2"),
	("OPL2", OPL2 + 5, 2, 128, "BAS"),		# bass
	("OPM",  OPM + 0, 0, OPM_C, "MEL"),		# brass
	("OPM",  OPM + 1, 0, OPM_L, "HAR"),
	("OPM",  OPM + 2, 1, OPM_L, "CH0"),		# electric piano
	("OPM",  OPM + 3, 1, OPM_C, "CH1"),
	("OPM",  OPM + 4, 1, OPM_R, "CH2"),
	("OPM",  OPM + 5, 2, OPM_C, "BAS"),		# bass
	("ADPCM", ADPCM, 0, 128, "DRM"),
]

# -----------------------------------------------------------------------------
#  Score (C major, 2/4). Absolute LilyPond pitches (c' = MIDI 60),
#  durations attached ("c''8"), omitted duration = previous one.
# -----------------------------------------------------------------------------
THEME = (
	"c''2 d''8 f'' e'' d'' g''4 g'' g''8 a'' e'' f'' d''4 d'' d''8 f'' e'' d'' "
	"c'' c''' b'' a'' g'' f'' e'' d'' "
	"c''2 d''8 f'' e'' d'' g''4 g'' g''8 a'' e'' f'' d''4 d'' d''8 f'' e'' d'' "
	"c'' g'' d'' e'' c''2"
)
# chord of each beat (2 beats / bar)
THEME_CHORDS = (
	"C C  G7 G7  C C  C C  G7 G7  G7 G7  C C  G7 G7 "
	"C C  G7 G7  C C  C C  G7 G7  G7 G7  C G7 C C"
).split()

CHORDS = {
	#        root bass, fifth bass, chord tones (pitch classes), voicing
	"C":  (48, 43, (0, 4, 7), (64, 67, 72)),
	"G7": (43, 50, (7, 11, 2, 5), (62, 65, 71)),
}

DRUM_KICK, DRUM_SNARE, DRUM_CRASH = 1, 2, 3

TOKEN_RE = re.compile(r"^([a-g](?:is|es)?|r)([',]*)(\d+\.?)?$")
BASE = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


def parse(text):
	"""Returns [(midi note or None, ticks)]."""
	out = []
	dur = UNIT // 4
	for tok in text.split():
		m = TOKEN_RE.match(tok)
		if not m:
			raise ValueError("bad token: " + tok)
		name, octs, d = m.groups()
		if d:
			dur = UNIT // int(d.rstrip("."))
			if d.endswith("."):
				dur += dur // 2
		if name == "r":
			out.append((None, dur))
			continue
		n = BASE[name[0]] + name.count("is") - name.count("es")
		out.append((48 + n + 12 * (octs.count("'") - octs.count(",")), dur))
	return out


def length(ev):
	return sum(d for _, d in ev)


def chord_at(chords, tick):
	return CHORDS[chords[tick // (BAR // 2)]]


def harmony(melody, chords):
	"""Highest chord tone at least a minor third below the melody note."""
	out = []
	t = 0
	for n, d in melody:
		if n is None:
			out.append((None, d))
		else:
			tones = chord_at(chords, t)[2]
			h = n - 3
			while h % 12 not in tones:
				h -= 1
			out.append((h, d))
		t += d
	return out


def bass_line(chords):
	out = []
	prev = None
	for i, c in enumerate(chords):
		root, fifth = CHORDS[c][0], CHORDS[c][1]
		n = fifth if (i % 2 == 1 and c == prev) else root
		out += [(n, BAR // 4), (None, BAR // 4)]
		prev = c
	return out


def chord_line(chords, voice):
	out = []
	for c in chords:
		out += [(None, BAR // 4), (CHORDS[c][3][voice], BAR // 4)]
	return out


def drum_line(bars, crash_first=True, fill_every=8):
	out = []
	for b in range(bars):
		if b == 0 and crash_first:
			out += [(DRUM_CRASH, BAR)]
		elif (b + 1) % fill_every == 0:
			out += [(DRUM_KICK, BAR // 4), (None, BAR // 4)] + [(DRUM_SNARE, BAR // 8)] * 4
		else:
			out += [(DRUM_KICK, BAR // 4), (None, BAR // 4), (DRUM_SNARE, BAR // 4), (None, BAR // 4)]
	return out


def transpose(ev, k):
	return [(None if n is None else n + k, d) for n, d in ev]


def rest(ticks):
	return [(None, ticks)]


# -----------------------------------------------------------------------------
def build_song():
	"""Returns ({channel index: events}, tempo map [(ticks, tempo60)])."""
	theme = parse(THEME)
	assert length(theme) == 16 * BAR
	assert len(THEME_CHORDS) == 32
	roles_theme = {
		"MEL": theme,
		"HAR": harmony(theme, THEME_CHORDS),
		"CH0": chord_line(THEME_CHORDS, 0),
		"CH1": chord_line(THEME_CHORDS, 1),
		"CH2": chord_line(THEME_CHORDS, 2),
		"BAS": bass_line(THEME_CHORDS),
	}

	sections = []		# [(ticks, {channel index: events}, tempo60)]

	# Intro: 4 bars of the accompaniment by all the chips, snare roll
	intro_chords = "C C C C G7 G7 G7 G7".split()
	intro = {}
	for i, (chip, hw, patch, pan, role) in enumerate(CHANNELS):
		if role == "BAS":
			intro[i] = bass_line(intro_chords)
		elif role.startswith("CH"):
			intro[i] = chord_line(intro_chords, int(role[2]))
		elif role == "DRM":
			intro[i] = ([(DRUM_CRASH, BAR)] + drum_line(2, False, 99)
				+ [(DRUM_SNARE, BAR // 8)] * 4 + [(DRUM_SNARE, BAR // 16)] * 8)
	sections.append((4 * BAR, intro, 168))

	# Theme by each chip, then tutti
	for feature in ("SSG", "SCC", "OPLL", "OPL2", "OPM", "ALL"):
		sec = {}
		for i, (chip, hw, patch, pan, role) in enumerate(CHANNELS):
			if role == "DRM":
				sec[i] = drum_line(16)
			elif chip == feature or feature == "ALL":
				ev = roles_theme[role]
				if feature == "ALL" and role == "MEL" and chip in ("SSG", "SCC"):
					ev = transpose(ev, 12)
				sec[i] = ev
		sections.append((16 * BAR, sec, 184 if feature == "ALL" else 168))

	# Coda: C - G - C
	coda = {}
	coda_notes = {
		"MEL": "c'''8 r g'' r c'''4 r",
		"HAR": "g''8 r f'' r g''4 r",
		"CH0": "e''8 r d'' r e''4 r",
		"CH1": "g'8 r f' r g'4 r",
		"CH2": "c''8 r b' r c''4 r",
		"BAS": "c8 r g, r c,4 r",
	}
	for i, (chip, hw, patch, pan, role) in enumerate(CHANNELS):
		if role == "DRM":
			coda[i] = [(DRUM_KICK, BAR // 4), (None, BAR // 4), (DRUM_KICK, BAR // 4), (None, BAR // 4), (DRUM_CRASH, BAR)]
		else:
			coda[i] = parse(coda_notes[role])
	sections.append((2 * BAR, coda, 150))

	parts = {i: [] for i in range(len(CHANNELS))}
	tempo = []
	for ticks, sec, t60 in sections:
		for i in parts:
			ev = sec.get(i, rest(ticks))
			assert length(ev) == ticks, (i, length(ev), ticks)
			parts[i] += ev
		tempo.append((ticks, t60))
	return parts, tempo


# -----------------------------------------------------------------------------
#  Stream encoding (same format as BRAND3)
# -----------------------------------------------------------------------------
def merge_rests(events):
	out = []
	for n, d in events:
		if n is None and out and out[-1][0] is None:
			out[-1] = (None, out[-1][1] + d)
		else:
			out.append((n, d))
	return out


def enc_len(t):
	if 1 <= t <= 0x6F:
		return [0x7F + t]
	return [0xF0, t & 0xFF, t >> 8]


def encode_part(events):
	out = []
	cur = None
	for n, d in merge_rests(events):
		if d != cur:
			out += enc_len(d)
			cur = d
		if n is None:
			out.append(0)
		else:
			assert 1 <= n <= 127
			out.append(n)
	out.append(0xFF)
	return out


def encode_conductor(tempo):
	out = []
	for ticks, t60 in tempo:
		t50 = min(255, (t60 * 6 + 2) // 5)
		out += [0xF8, t60, t50]
		out += enc_len(ticks) if ticks <= 0x6F else [0xF0, ticks & 0xFF, ticks >> 8]
		out.append(0)
	out.append(0xFF)
	return out


def tempo60(bpm):
	"""quarter = bpm -> ticks per frame x 256 at 60Hz"""
	return int(round(bpm / 60.0 * (UNIT / 4) / 60.0 * 256))


# -----------------------------------------------------------------------------
#  Pitch tables
# -----------------------------------------------------------------------------
def freq(n):
	return 440.0 * 2.0 ** ((n - 69) / 12.0)


def opm_kc(n):
	n = max(13, min(n, 13 + 8 * 12 - 1))
	oct_ = (n - 13) // 12
	note = [0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14][(n - 13) % 12]
	return (oct_ << 4) | note


def fm_fnum(n, bits, shift):
	for block in range(8):
		fnum = int(round(freq(n) * (1 << (shift - block)) / FM_FS))
		if fnum < (1 << bits):
			return fnum, block
	return (1 << bits) - 1, 7


def opl_word(n):
	fnum, block = fm_fnum(n, 10, 20)
	return fnum | (block << 10)			# A0h = low, B0h = block << 2 | fnum >> 8


def opll_word(n):
	fnum, block = fm_fnum(n, 9, 19)
	return fnum | (block << 9)			# 10h = low, 20h = block << 1 | fnum >> 8


def scc_word(n):
	return max(0, min(4095, int(round(CLOCK / (32.0 * freq(n)))) - 1))


def ssg_word(n):
	return max(1, min(4095, int(round(SSG_CLOCK / (16.0 * freq(n))))))


# -----------------------------------------------------------------------------
#  ADPCM drum samples (Y8950 ADPCM, same algorithm as y8960_adpcm_test)
# -----------------------------------------------------------------------------
ADPCM_DELTA_N = 0x5555
ADPCM_FS = FM_FS * ADPCM_DELTA_N / 65536.0
F1 = [1, 3, 5, 7, 9, 11, 13, 15, -1, -3, -5, -7, -9, -11, -13, -15]
F2 = [57, 57, 57, 57, 77, 102, 128, 153] * 2


def _tdiv(a, b):
	return int(a / b)


def adpcm_encode(signal):
	acc, step, nib = 0, 127, []
	for x in signal:
		d = int(x) - acc
		n = (8 if d < 0 else 0) | min(7, (abs(d) * 4) // step)
		nib.append(n)
		acc = max(-32768, min(32767, acc + _tdiv(F1[n] * step, 8)))
		step = max(127, min(24576, _tdiv(step * F2[n], 64)))
	return bytes((nib[i] << 4) | nib[i + 1] for i in range(0, len(nib), 2))


def synth_drums():
	rnd = random.Random(1858)
	fs = ADPCM_FS

	def env(t, tau):
		return math.exp(-t / tau)

	def finish(sig, amp):
		peak = max(1e-9, max(abs(x) for x in sig))
		sig = [x / peak * amp for x in sig]
		sig += [0.0] * ((-len(sig)) % 8 + 8)		# 4-byte unit + silent tail
		return adpcm_encode(sig)

	# kick: pitch sweep 160Hz -> 45Hz
	n = int(fs * 0.22)
	sig, ph = [], 0.0
	for i in range(n):
		t = i / fs
		f = 45.0 + 115.0 * math.exp(-t / 0.03)
		ph += 2 * math.pi * f / fs
		sig.append(math.sin(ph) * env(t, 0.07) + (rnd.uniform(-1, 1) * env(t, 0.003) * 0.4))
	kick = finish(sig, 26000)

	# snare: noise + 190Hz body
	n = int(fs * 0.18)
	sig, prev = [], 0.0
	for i in range(n):
		t = i / fs
		w = rnd.uniform(-1, 1)
		hp = w - prev * 0.6
		prev = w
		sig.append(hp * env(t, 0.05) * 0.8 + math.sin(2 * math.pi * 190 * t) * env(t, 0.03) * 0.6)
	snare = finish(sig, 22000)

	# crash cymbal (+ kick at the head)
	n = int(fs * 1.1)
	sig, p1, p2 = [], 0.0, 0.0
	for i in range(n):
		t = i / fs
		w = rnd.uniform(-1, 1)
		hp = w - 2 * p1 + p2					# 2nd order difference (bright)
		p2, p1 = p1, w
		s = hp * 0.35 * env(t, 0.35) * (1.0 - env(t, 0.004))
		if i < len(kick) * 2:
			f = 45.0 + 115.0 * math.exp(-t / 0.03)
			s += math.sin(2 * math.pi * f * t) * env(t, 0.07) * 0.8
		sig.append(s)
	crash = finish(sig, 22000)
	return [kick, snare, crash]


# -----------------------------------------------------------------------------
def db_lines(data, per=16):
	return ["\t\t\tdb\t\t" + ", ".join("0x%02X" % b for b in data[i:i + per])
		for i in range(0, len(data), per)]


def word_table(name, words):
	data = []
	for w in words:
		data += [w & 0xFF, w >> 8]
	return [name + ":"] + db_lines(data)


def main():
	parts, tempo = build_song()
	tempo = [(t, tempo60(bpm)) for t, bpm in tempo]
	lines = [
		"; -----------------------------------------------------------------------------",
		"; cancan.inc  (generated by mkcancan.py, do not edit)",
		"; -----------------------------------------------------------------------------",
		"song_table:",
		"\t\t\tdb\t\t%d" % (len(CHANNELS) + 1),
		"\t\t\tdb\t\t0x%02X, 0, 0" % COND,
		"\t\t\tdw\t\tstream_cond",
	]
	for i, (chip, hw, patch, pan, role) in enumerate(CHANNELS):
		lines.append("\t\t\tdb\t\t0x%02X, 0x%02X, 0x%02X\t\t; %s %s" % (hw, patch, pan, chip, role))
		lines.append("\t\t\tdw\t\tstream_%d" % i)

	total = 0
	data = encode_conductor(tempo)
	total += len(data)
	lines.append("stream_cond:")
	lines += db_lines(data)
	for i in range(len(CHANNELS)):
		data = encode_part(parts[i])
		total += len(data)
		lines.append("stream_%d:" % i)
		lines += db_lines(data)

	lines.append("opm_kc_table:")
	lines += db_lines([opm_kc(n) for n in range(128)])
	lines += word_table("opl_fnum_table", [opl_word(n) for n in range(128)])
	lines += word_table("opll_fnum_table", [opll_word(n) for n in range(128)])
	lines += word_table("scc_freq_table", [scc_word(n) for n in range(128)])
	lines += word_table("ssg_tone_table", [ssg_word(n) for n in range(128)])

	# SCC waveforms (32 bytes each): 0 = saw, 1 = square, 2 = triangle
	waves = [
		[int(round((15.5 - i) * 6.5)) for i in range(32)],
		[88] * 16 + [-88] * 16,
		[int(round(112 * (1.0 - 4.0 * abs((i + 0.5) / 32.0 - 0.5)))) for i in range(32)],
	]
	lines.append("scc_waves:")
	for w in waves:
		lines += db_lines([v & 0xFF for v in w])

	# ADPCM samples: table of { start, stop } in 4-byte units (drum note 1..)
	drums = synth_drums()
	lines.append("ADPCM_DELTA_N\t:= 0x%04X" % ADPCM_DELTA_N)
	lines.append("adpcm_table:")
	addr = 0
	for d in drums:
		lines.append("\t\t\tdw\t\t0x%04X, 0x%04X" % (addr // 4, (addr + len(d)) // 4 - 1))
		addr += len(d)
	lines.append("ADPCM_SIZE\t:= %d" % addr)
	lines.append("ADPCM_STOP\t:= 0x%04X" % (addr // 4 - 1))
	lines.append("adpcm_data:")
	lines += db_lines(b"".join(drums))

	with open(os.path.join(HERE, "cancan.inc"), "w", newline="\r\n") as f:
		f.write("\n".join(lines) + "\n")
	frames = sum(t * 256.0 / t60 for t, t60 in tempo)
	print("stream bytes = %d, adpcm bytes = %d, play time = %.1f sec (60Hz)" % (total, addr, frames / 60.0))


if __name__ == "__main__":
	main()
