# -----------------------------------------------------------------------------
#  mkopllrhy.py
#   Generates the song data (opllrhy.inc) of OPLLRHY.COM:
#   an original 8-beat tune for the OPLL of the Y8960 Cartridge, using the
#   rhythm mode (all 5 drums) and 6 melody channels.
#
#   Usage: python mkopllrhy.py          -> writes opllrhy.inc
# -----------------------------------------------------------------------------
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
UNIT = 64				# ticks per whole note (16th = 4 ticks)
BAR = UNIT				# 4/4
STEP = UNIT // 16		# 16th note

CLOCK = 3579545.0
FM_FS = CLOCK / 72.0

# hw channel numbers
OPLL, RHY, COND = 0x20, 0x60, 0xFF

# -----------------------------------------------------------------------------
#  Melody channels: (hw channel, patch = INST << 4 | VOL, pan, role)
#   INST: 1 violin, 2 guitar, 3 piano, 4 flute, 5 clarinet, 6 oboe,
#         7 trumpet, 8 organ, 9 horn, 10 synthesizer, 11 harpsichord,
#         12 vibraphone, 13 synth bass, 14 acoustic bass, 15 electric guitar
#   VOL : 0 = max ... 15 = min (3dB step)
#   pan : 0 = left, 128 = center, 255 = right (Y8960 extension, 50h-55h)
# -----------------------------------------------------------------------------
CHANNELS = [
	(OPLL + 0, 0x40, 128, "MEL"),		# flute
	(OPLL + 1, 0x52,  80, "HAR"),		# clarinet
	(OPLL + 2, 0x33,  48, "CH0"),		# piano
	(OPLL + 3, 0x33, 128, "CH1"),
	(OPLL + 4, 0x33, 208, "CH2"),
	(OPLL + 5, 0xE0, 128, "BAS"),		# acoustic bass
]

# -----------------------------------------------------------------------------
#  Rhythm (ch6-8). Volume: 0 = max ... 15 = min.
#   PAN: BD = ch7 (56h), HH/SD = ch8 (57h), TOM/CYM = ch9 (58h)
# -----------------------------------------------------------------------------
RHYTHM_VOLUME = {"BD": 0, "SD": 0, "TOM": 0, "CYM": 0, "HH": 0}
RHYTHM_PAN = (128, 128, 128)			# ch7, ch8, ch9
RHYTHM_FNUM = ((0x20, 0x05), (0x50, 0x05), (0xC0, 0x01))	# (1xh, 2xh) of ch7-9

BD, SD, TOM, CYM, HH = 0x10, 0x08, 0x04, 0x02, 0x01

# -----------------------------------------------------------------------------
#  Score (C major, 4/4). Absolute LilyPond pitches (c' = MIDI 60),
#  durations attached ("c''8"), omitted duration = previous one.
# -----------------------------------------------------------------------------
THEME_A = (
	"e''4 g''8 e'' c''4 g' "
	"a'8 c'' e'' a'' g''4 e'' "
	"f''4 a''8 f'' c''4 a' "
	"b'8 d'' g'' b'' a''4 g'' "
	"e''4 g''8 e'' c'''4 g'' "
	"a''8 g'' e'' c'' a'4 c'' "
	"f''8 e'' d'' c'' d''4 b' "
	"c''2. r4"
)
CHORDS_A = "C C  Am Am  F F  G G  C C  Am Am  F G  C C".split()

THEME_B = (
	"a''4. g''8 f''4 e'' "
	"d''4. e''8 f''4 g'' "
	"g''4. f''8 e''4 d'' "
	"c''2 e'' "
	"f''4. e''8 d''4 f'' "
	"b''4. a''8 g''4 f'' "
	"e''8 f'' g'' a'' c'''4 a'' "
	"g''2 b'4 d''"
)
CHORDS_B = "F F  G G  Em Em  Am Am  Dm Dm  G G  F F  G G".split()

CHORDS = {
	#       bass, chord tones (pitch classes), piano voicing
	"C":  (36, (0, 4, 7),  (60, 64, 67)),
	"Dm": (38, (2, 5, 9),  (57, 62, 65)),
	"Em": (40, (4, 7, 11), (59, 64, 67)),
	"F":  (41, (5, 9, 0),  (57, 60, 65)),
	"G":  (43, (7, 11, 2), (59, 62, 67)),
	"Am": (45, (9, 0, 4),  (57, 60, 64)),
}

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


def rest(ticks):
	return [(None, ticks)]


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
			tones = chord_at(chords, t)[1]
			h = n - 3
			while h % 12 not in tones:
				h -= 1
			out.append((h, d))
		t += d
	return out


def bass_line(chords):
	"""8th notes on the root, the octave on the 4th and 8th 8ths."""
	out = []
	for c in chords:
		root = CHORDS[c][0]
		out += [(root, UNIT // 8), (root, UNIT // 8), (root, UNIT // 8), (root + 12, UNIT // 8)]
	return out


def chord_line(chords, voice):
	"""Piano: quarter notes on every beat."""
	out = []
	for c in chords:
		out += [(CHORDS[c][2][voice], UNIT // 4)] * 2
	return out


# -----------------------------------------------------------------------------
#  Drums: 16 steps (16th notes) per bar, each step is a mask of BD|SD|TOM|CYM|HH
# -----------------------------------------------------------------------------
def bar_basic(crash=False):
	s = [0] * 16
	for i in range(0, 16, 2):
		s[i] |= HH
	s[0] |= BD
	s[6] |= BD
	s[8] |= BD
	s[4] |= SD
	s[12] |= SD
	if crash:
		s[0] = (s[0] & ~HH) | CYM
	return s


def bar_ride(crash=False):
	"""Cymbal on every beat instead of the hi-hat."""
	s = [0] * 16
	for i in range(0, 16, 4):
		s[i] |= CYM
	s[0] |= BD
	s[6] |= BD
	s[8] |= BD
	s[10] |= BD
	s[4] |= SD
	s[12] |= SD
	for i in (2, 6, 10, 14):
		s[i] |= HH
	return s


def bar_fill():
	s = bar_basic()[:8] + [SD, SD, TOM, TOM, SD, TOM, TOM, BD | SD]
	return s


def drum_section(kinds):
	"""kinds: list of bar names"""
	steps = []
	for k in kinds:
		steps += {
			"basic": bar_basic(),
			"crash": bar_basic(True),
			"ride": bar_ride(),
			"ridecrash": bar_ride(True),
			"fill": bar_fill(),
		}[k]
	return steps


def drum_demo():
	"""Each drum alone for one bar, then all together."""
	steps = []
	steps += [BD, 0, 0, 0] * 4
	steps += [SD, 0, 0, 0] * 4
	steps += [TOM, 0, 0, 0] * 4
	steps += [CYM] + [0] * 7 + [CYM] + [0] * 7
	steps += [HH, 0] * 8
	steps += [BD | SD | TOM | CYM | HH] + [0] * 15
	return steps


def steps_to_events(steps):
	return [(m if m else None, STEP) for m in steps]


# -----------------------------------------------------------------------------
def build_song():
	"""Returns ({part name: events}, tempo map [(ticks, bpm)])."""
	theme_a = parse(THEME_A)
	theme_b = parse(THEME_B)
	assert length(theme_a) == 8 * BAR and len(CHORDS_A) == 16
	assert length(theme_b) == 8 * BAR and len(CHORDS_B) == 16

	def melody_section(theme, chords):
		return {
			"MEL": theme,
			"HAR": harmony(theme, chords),
			"CH0": chord_line(chords, 0),
			"CH1": chord_line(chords, 1),
			"CH2": chord_line(chords, 2),
			"BAS": bass_line(chords),
		}

	sections = []		# [(ticks, {part: events}, bpm)]

	# Drum demo: BD, SD, TOM, CYM, HH, all (6 bars)
	sections.append((6 * BAR, {"RHY": steps_to_events(drum_demo())}, 120))

	# A, B, A, ending
	sec = melody_section(theme_a, CHORDS_A)
	sec["RHY"] = steps_to_events(drum_section(["crash"] + ["basic"] * 6 + ["fill"]))
	sections.append((8 * BAR, sec, 120))

	sec = melody_section(theme_b, CHORDS_B)
	sec["RHY"] = steps_to_events(drum_section(["ridecrash"] + ["ride"] * 6 + ["fill"]))
	sections.append((8 * BAR, sec, 120))

	sec = melody_section(theme_a, CHORDS_A)
	sec["RHY"] = steps_to_events(drum_section(["crash"] + ["basic"] * 6 + ["fill"]))
	sections.append((8 * BAR, sec, 120))

	ending = {
		"MEL": parse("c'''1 r1"),
		"HAR": parse("g''1 r1"),
		"CH0": parse("e''1 r1"),
		"CH1": parse("g'1 r1"),
		"CH2": parse("c''1 r1"),
		"BAS": parse("c,1 r1"),
		"RHY": steps_to_events([BD | CYM] + [0] * 31),
	}
	sections.append((2 * BAR, ending, 120))

	names = [role for _, _, _, role in CHANNELS] + ["RHY"]
	parts = {n: [] for n in names}
	tempo = []
	for ticks, sec, bpm in sections:
		for n in names:
			ev = sec.get(n, rest(ticks))
			assert length(ev) == ticks, (n, length(ev), ticks)
			parts[n] += ev
		tempo.append((ticks, bpm))
	return parts, tempo


# -----------------------------------------------------------------------------
#  Stream encoding (same format as CANCAN)
# -----------------------------------------------------------------------------
def merge_rests(events):
	out = []
	for n, d in events:
		if n is None and out and out[-1][0] is None:
			out[-1] = (None, out[-1][1] + d)
		else:
			out.append((n, d))
	return out


def attach_rests(events):
	"""Drums: a rest after a hit is merged into the hit (no key off needed)."""
	out = []
	for n, d in events:
		if n is None and out:
			out[-1] = (out[-1][0], out[-1][1] + d)
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
	for n, d in events:
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
		out += enc_len(ticks)
		out.append(0)
	out.append(0xFF)
	return out


def tempo60(bpm):
	"""quarter = bpm -> ticks per frame x 256 at 60Hz"""
	return int(round(bpm / 60.0 * (UNIT / 4) / 60.0 * 256))


def freq(n):
	return 440.0 * 2.0 ** ((n - 69) / 12.0)


def opll_word(n):
	for block in range(8):
		fnum = int(round(freq(n) * (1 << (19 - block)) / FM_FS))
		if fnum < 512:
			return fnum | (block << 9)		# 10h = low, 20h = block << 1 | fnum >> 8
	return 511 | (7 << 9)


def db_lines(data, per=16):
	return ["\t\t\tdb\t\t" + ", ".join("0x%02X" % b for b in data[i:i + per])
		for i in range(0, len(data), per)]


def main():
	parts, tempo = build_song()
	tempo = [(t, tempo60(bpm)) for t, bpm in tempo]
	lines = [
		"; -----------------------------------------------------------------------------",
		"; opllrhy.inc  (generated by mkopllrhy.py, do not edit)",
		"; -----------------------------------------------------------------------------",
		"opll_init_table:\t\t\t\t; { register, data }, terminated by FFh",
	]
	v = RHYTHM_VOLUME
	init = []
	for ch in range(3):
		init += [0x16 + ch, RHYTHM_FNUM[ch][0], 0x26 + ch, RHYTHM_FNUM[ch][1]]
	init += [0x36, v["BD"], 0x37, (v["HH"] << 4) | v["SD"], 0x38, (v["TOM"] << 4) | v["CYM"]]
	for ch in range(3):
		init += [0x46 + ch, 0x00, 0x56 + ch, RHYTHM_PAN[ch]]
	init += [0x0E, 0x20, 0xFF]
	lines += db_lines(init)

	lines += [
		"song_table:",
		"\t\t\tdb\t\t%d" % (len(CHANNELS) + 2),
		"\t\t\tdb\t\t0x%02X, 0, 0" % COND,
		"\t\t\tdw\t\tstream_cond",
	]
	for hw, patch, pan, role in CHANNELS:
		lines.append("\t\t\tdb\t\t0x%02X, 0x%02X, 0x%02X\t\t; %s" % (hw, patch, pan, role))
		lines.append("\t\t\tdw\t\tstream_%s" % role.lower())
	lines.append("\t\t\tdb\t\t0x%02X, 0, 0\t\t; rhythm" % RHY)
	lines.append("\t\t\tdw\t\tstream_rhy")

	lines.append("stream_cond:")
	lines += db_lines(encode_conductor(tempo))
	for _, _, _, role in CHANNELS:
		lines.append("stream_%s:" % role.lower())
		lines += db_lines(encode_part(merge_rests(parts[role])))
	lines.append("stream_rhy:")
	lines += db_lines(encode_part(attach_rests(parts["RHY"])))

	data = []
	for n in range(128):
		w = opll_word(n)
		data += [w & 0xFF, w >> 8]
	lines.append("opll_fnum_table:")
	lines += db_lines(data)

	with open(os.path.join(HERE, "opllrhy.inc"), "w", newline="\r\n") as f:
		f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
	main()
