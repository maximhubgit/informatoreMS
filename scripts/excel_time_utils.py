"""Parsing delle celle orario del foglio Excel.

Una cella puo' contenere:
- testo chiave: "mattina" / "pomeriggio" / "tutto il giorno"
- un intervallo singolo: "8,30 - 13,00" / "12-14"
- piu' intervalli separati da "\\n" o ";" o "|": "11,00 - 12,30\\n15,00 - 17,00"
- rumore da ignorare: "si" / "?" / "14" / "ora f..."

Strategia di default (scelta utente):
- piu' intervalli nella stessa cella vengono CONCATENATI in un'unica fascia
  con minutiInizio = min degli inizi e minutiFine = max dei fine.

Restituisce (minutiInizio, minutiFine) in minuti dalla mezzanotte,
oppure None se la cella non produce un intervallo utilizzabile.
"""
from __future__ import annotations

import re
from typing import Optional, Tuple

# Parole chiave testuali
MATTINA = (8 * 60, 12 * 60)        # 08:00 - 12:00
POMERIGGIO = (15 * 60, 18 * 60)    # 15:00 - 18:00
TUTTO_GIORNO = (8 * 60, 18 * 60)   # 08:00 - 18:00

# Pattern che cattura un intervallo "H,M - H,M" / "H.M-H.M" / "H-H"
# Accetta separatori: . , : oppure nessuno (es. "8-13").
# Usa [.,:]+ opzionale per separatore decimali (virgola italiana o punto).
INTERVAL_RE = re.compile(
    r"""
    (\d{1,2})             # ore inizio
    [.,:]?                # separatore decimale opzionale
    (\d{0,2})             # minuti inizio (opzionale)
    \s*                   # spazi opzionali
    [-–—]                 # trattino semplice, en-dash, em-dash
    \s*                   # spazi opzionali
    (\d{1,2})             # ore fine
    [.,:]?                # separatore decimale opzionale
    (\d{0,2})             # minuti fine (opzionale)
    """,
    re.VERBOSE,
)


def _parse_time(hours: str, minutes: str) -> Optional[int]:
    """Converte (ore, minuti) in minuti totali dalla mezzanotte."""
    try:
        h = int(hours)
        m = int(minutes) if minutes else 0
    except ValueError:
        return None
    if h < 0 or h > 23 or m < 0 or m > 59:
        return None
    return h * 60 + m


def _keyword_match(text_lower: str) -> Optional[Tuple[int, int]]:
    """Riconosce le parole chiave testuali 'mattina', 'pomeriggio', 'tutto il giorno'.

    L'ordine conta: 'tutto il giorno' va controllato prima di 'mattina' perche'
    contiene 'tutto' ma non deve matchare 'mattina'.
    """
    if "tutto il giorno" in text_lower or "tutta la giornata" in text_lower:
        return TUTTO_GIORNO
    # mattina / mattino / matt.
    if re.search(r"\bmattin[oa]\b", text_lower):
        return MATTINA
    # pomeriggio / pomeriggio?
    if re.search(r"\bpomerigg[iio]+", text_lower):
        return POMERIGGIO
    return None


def _interval_match(text: str) -> Optional[Tuple[int, int]]:
    """Cerca tutti gli intervalli 'H-H' / 'H,M-H,M' nel testo e li concatena.

    Restituisce (min_start, max_end) oppure None.
    Piu' intervalli nella stessa stringa vengono fusi in uno solo
    (scelta utente: concatena in fascia unica).
    """
    starts: list[int] = []
    ends: list[int] = []
    for m in INTERVAL_RE.finditer(text):
        start = _parse_time(m.group(1), m.group(2))
        end = _parse_time(m.group(3), m.group(4))
        if start is None or end is None:
            continue
        if end < start:
            # Intervallo invertito o degeneri: lo ignoriamo
            continue
        starts.append(start)
        ends.append(end)
    if not starts:
        return None
    return (min(starts), max(ends))


def parse_time_cell(value) -> Optional[Tuple[int, int]]:
    """Punto di ingresso unico: data una cella Excel, ritorna (inizio, fine) o None.

    Args:
        value: contenuto della cella (stringa, numero o None).

    Returns:
        Tupla (minutiInizio, minutiFine) oppure None se la cella e' vuota /
        non produce un intervallo utilizzabile.
    """
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    text_lower = text.lower()

    # 1) Match parole chiave
    keyword = _keyword_match(text_lower)
    if keyword is not None:
        return keyword

    # 2) Match intervalli orari
    interval = _interval_match(text)
    if interval is not None:
        return interval

    # 3) Nessun match utile
    return None


def minutes_to_hhmm(minutes: int) -> str:
    """Formatta un numero di minuti come stringa 'HH:MM'."""
    h = minutes // 60
    m = minutes % 60
    return f"{h:02d}:{m:02d}"


if __name__ == "__main__":
    # Test rapidi
    cases = [
        ("mattina", (480, 720)),
        ("pomeriggio", (900, 1080)),
        ("tutto il giorno", (480, 1080)),
        ("8,30 - 13,00", (510, 780)),
        ("11,00 - 12,30\n15,00 - 17,00", (660, 1020)),
        ("12-14; 15-18", (720, 1080)),
        ("", None),
        ("si", None),
        ("?", None),
        ("14", None),
        ("8,30 - 13,00\n14,30 - 18,00", (510, 1080)),
        ("11,00 - 12,30", (660, 750)),
        ("14,30 --->", None),
        ("dalle 16,00", None),
        (None, None),
        ("16,00 - 17,00", (960, 1020)),
        ("  mattina  ", (480, 720)),
        ("MATTINA", (480, 720)),
        ("pomeriggio?", (900, 1080)),
    ]
    for value, expected in cases:
        result = parse_time_cell(value)
        status = "OK" if result == expected else "FAIL"
        print(f"[{status}] parse({value!r}) = {result} (atteso: {expected})")
