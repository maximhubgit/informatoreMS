"""Estrazione di numeri di telefono da testo libero.

I telefoni compaiono nel foglio Excel in vari formati:
- 'tel 081 769.10.20'
- 'cell 338 93.47.116'
- 'cell 389 94 05 839'
- '081 780 80 51'  (senza prefisso parola chiave)
- '(081 64 57 03 - 328 53 53 929 - 330 82 ...'
- 'segr Chiara cell 320 222 80 60'
- 'Roberta 342 190.35....'

L'estrattore cattura sequenze che sembrano numeri telefonici italiani:
- cellulari 3xx xxx xxxx (10 cifre)
- fissi 0xx xxx xxxx (fino a 11 cifre)
- opzionale prefisso +39 internazionale.

Vengono deduplati (stesso numero anche con formattazione diversa) e concatenati con ' | '.
"""
from __future__ import annotations

import re
from typing import Iterable, Optional

# Cattura un numero italiano: opzionale +39, poi 0xx (fisso) o 3xx (cellulare).
# Le cifre successive possono essere separate da spazi o punti (NO trattino,
# perche' nel dataset il '-' separa telefoni distinti, es. '081 - 328 - 330').
# I gruppi sono 1-5 (per accettare anche numeri incompleti tipo '342 190.35').
PHONE_RE = re.compile(
    r"""
    (?<!\d)                                  # word boundary (no digit before)
    (\+?39[\s.\-]?)?                         # prefisso internazionale opzionale
    ((?:3\d{2}|0\d{1,3}))                    # prefisso 3xx o 0xx
    (?:[\s.]?\d+){1,5}                       # 1-5 gruppi di cifre separate da spazio/punto
    (?!\d)                                   # no digit immediately after
    """,
    re.VERBOSE,
)


def _clean_display(raw: str) -> str:
    """Ripulisce un match per la visualizzazione: collassa spazi, rimuove
    keyword prefixes (tel/cell/studio/...), mantiene separatori (./space/-).
    """
    # Rimuovi keyword iniziali comuni
    s = re.sub(r"^\s*(?:tel|cell|studio|stusdio|cell\.?|segr\.?)\s+", "", raw, flags=re.IGNORECASE)
    # Rimuovi parentesi tonde di apertura
    s = s.lstrip("(")
    # Collassa spazi multipli
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _dedup_key(display: str) -> str:
    """Chiave per dedup: tutte le cifre, per consentire match cross-formato."""
    return re.sub(r"\D", "", display)


def extract_phones(*texts: Optional[str]) -> list[str]:
    """Estrae tutti i numeri di telefono dai testi forniti.

    Args:
        *texts: uno o piu' testi (None ammesso).

    Returns:
        Lista di numeri normalizzati, deduplati per sequenza di cifre,
        filtrati per lunghezza minima (>=9 cifre).
    """
    seen: dict[str, str] = {}  # dedup_key -> display
    for text in texts:
        if not text:
            continue
        for m in PHONE_RE.finditer(text):
            raw = m.group(0)
            display = _clean_display(raw)
            key = _dedup_key(display)
            # Filtra numeri troppo corti (probabilmente incompleti o falsi positivi)
            if len(key) < 9:
                continue
            if key not in seen:
                seen[key] = display
    return list(seen.values())


def join_phones(phones: Iterable[str]) -> str:
    """Concatena una lista di telefoni con ' | ' per il campo Medico.telefono."""
    return " | ".join(phones)


if __name__ == "__main__":
    # Test rapidi
    cases = [
        ("tel 081 769.10.20",),
        ("cell 338 93.47.116",),
        ("cell 389 94 05 839",),
        ("081 780 80 51",),
        ("081 64 57 03 - 328 53 53 929 - 330 82 ...",),
        ("segr Chiara cell 320 222 80 60",),
        ("Roberta 342 190.35....",),
        ("081 526.61.31",),
        ("",),
        (None,),
        ("stusdio 081 552 18 26",),
        ("studio 081 40 46 14                 cell 333 54 21 433",),
        ("081 64 20 89                         368 357 68 69",),
        ("081 18 84 10 71",),
    ]
    for case in cases:
        result = extract_phones(*case)
        print(f"extract({case[0]!r}) = {result}")
