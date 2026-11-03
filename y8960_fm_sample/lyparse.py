# -----------------------------------------------------------------------------
#  lyparse.py
#   Minimal parser for the LilyPond subset written by Rosegarden (and by hand
#   in the same style): absolute pitches (nederlands names), durations,
#   rests, multi-measure rests. One monophonic voice per staff.
# -----------------------------------------------------------------------------
import re

NOTE_RE = re.compile(r"^([a-g])((?:is|es|s)*)([',]*)$")
DUR_RE = re.compile(r"^(\d+)(\.*)(?:\*(\d+)(?:/(\d+))?)?$")
REST_RE = re.compile(r"^([rR])(\d+\.*(?:\*\d+(?:/\d+)?)?)?$")
STAFF_RE = re.compile(r'\\context Staff = "track (\d+), ([^"]*)"')
BASE = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


def _dur_ticks(m, unit):
	# unit = ticks per whole note
	base = int(m.group(1))
	t = unit // base
	add = t
	for _ in m.group(2):
		add //= 2
		t += add
	if m.group(3):
		t = t * int(m.group(3)) // int(m.group(4) or 1)
	return t


def _pitch(m):
	name, acc, octs = m.groups()
	n = BASE[name]
	if acc:
		# nederlands: "is" sharp, "es"/"s" flat ("as", "es", "ees" ...)
		n += acc.count("is")
		n -= acc.count("es")
		if acc == "s":
			n -= 1
	o = octs.count("'") - octs.count(",")
	return 48 + 12 * o + n			# c' = 60 (MIDI)


def parse_voice(text, unit=64):
	"""Returns a list of (midi_note or None, ticks)."""
	text = re.sub(r"[_^-]?\\markup\s*\{[^{}]*\}", " ", text)
	text = re.sub(r'\\bar\s+"[^"]*"', " ", text)
	text = re.sub(r"%[^\n]*", " ", text)
	events = []
	dur = unit // 4
	pending = None		# index of the last note/rest awaiting a duration
	for tok in text.split():
		m = NOTE_RE.match(tok)
		if m:
			events.append([_pitch(m), dur])
			pending = len(events) - 1
			continue
		m = REST_RE.match(tok)
		if m:
			events.append([None, dur])
			pending = len(events) - 1
			if m.group(2):
				dm = DUR_RE.match(m.group(2))
				dur = _dur_ticks(dm, unit)
				events[-1][1] = dur
				pending = None
			continue
		m = DUR_RE.match(tok)
		if m:
			if pending is None:
				raise ValueError("duration without note: " + tok)
			dur = _dur_ticks(m, unit)
			events[pending][1] = dur
			pending = None
			continue
		if tok in ("[", "]", "|", "(", ")", "_(", "^(", "~") or tok.startswith("-\\") or tok.startswith("\\"):
			continue
		raise ValueError("unknown token: " + tok)
	return [tuple(e) for e in events]


def parse_rosegarden(path, unit=64):
	"""Returns [(name, events)] for each staff of a Rosegarden LilyPond file."""
	src = open(path, encoding="utf-8").read()
	staves = []
	for m in STAFF_RE.finditer(src):
		start = src.index("\\context Voice", m.end())
		start = src.index("{", start) + 1
		end = src.index("} % Voice", start)
		body = []
		for line in src[start:end].splitlines():
			s = line.strip()
			if not s or s.startswith("\\") and not s.startswith("\\markup"):
				continue
			body.append(s)
		staves.append((m.group(2), parse_voice("\n".join(body), unit)))
	return staves
