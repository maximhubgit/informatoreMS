"""Parser del foglio Excel 'Elenco dottori 2025.xlsx'.

Struttura del file (riga 1 vuota, riga 2 = intestazioni, dati da riga 3):
- Colonna 1 (Nome): puo' essere un medico, una riga ASL o una riga Distretto.
- Colonne 3-7 (Lun-Ven): celle orario per ogni giorno della settimana.
- Colonna 8 (note): annotazioni libere.
- Colonna 9 (Specializzazione): match contro tabella Firebase specializzazioni.
- Colonna 10 (Struttura): struttura/ente.
- Colonna 11 (Zona): zona di appartenenza.
- Colonna 12 (Prodotto): prodotti/terapie.

Il parser restituisce strutture dati pronte per essere scritte su Firestore.
Non conosce Firebase: riceve il dizionario delle specializzazioni dal chiamante.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional

from excel_time_utils import parse_time_cell
from phone_extractor import extract_phones, PHONE_RE


# ----------------------------------------------------------------------------
# Strutture dati di output
# ----------------------------------------------------------------------------

@dataclass
class AslRecord:
    codice: int
    descrizione: str


@dataclass
class DistrettoRecord:
    codice: int
    nr_distretto: int
    descrizione: str
    codice_asl: int


@dataclass
class ZonaRecord:
    nome: str
    colore_hex: str


@dataclass
class FasciaRecord:
    nr: int
    minuti_inizio: int
    minuti_fine: int
    giorni_settimana: list[str]   # nomi: ['lunedi', 'martedi', ...]
    distretto_id: int
    zona_id: Optional[str]        # None = verrà risolto dopo lookup zone
    struttura: Optional[str]
    indirizzo: Optional[str]
    is_fittizia: bool = False     # True = fascia "segnaposto" 00:00-00:00 domenica
                                  # usata solo per conservare i dati anagrafici
                                  # (asl, distretto, zona, struttura, indirizzo) di
                                  # un medico che non ha orari reali. Esclusa dalla
                                  # pianificazione dello scheduler.
    id_area: Optional[str] = None  # area collegata alla fascia (da codArea in Excel)


@dataclass
class MedicoRecord:
    nome: str
    telefono: Optional[str]
    specializzazione_id: str
    prodotti: Optional[str]
    annotazioni: Optional[str]
    periodicita_giorni: int = 30
    fasce: list[FasciaRecord] = field(default_factory=list)


@dataclass
class ParseResult:
    asl: list[AslRecord] = field(default_factory=list)
    distretti: list[DistrettoRecord] = field(default_factory=list)
    zone: list[ZonaRecord] = field(default_factory=list)
    medici: list[MedicoRecord] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ----------------------------------------------------------------------------
# Costanti
# ----------------------------------------------------------------------------

# Mappatura descrizione ASL -> codice SSN reale.
# Match effettuato in lower-case con regex.
ASL_PATTERNS = [
    (re.compile(r"asl\s+1\s+napoli|napoli\s+1|asl\s+1\b", re.IGNORECASE), 201),
    (re.compile(r"asl\s+napoli\s+2|napoli\s+2|asl\s+2\b", re.IGNORECASE), 202),
    (re.compile(r"asl\s+napoli\s+3|napoli\s+3|asl\s+3\b", re.IGNORECASE), 203),
    (re.compile(r"asl\s+caserta", re.IGNORECASE), 101),
]

# Pattern per riconoscere una riga distretto (case-insensitive, gestisce typo).
DISTRETTO_RE = re.compile(
    r"^\s*d[iy]?str?etto\s+(\d+)\s*(.*)$",
    re.IGNORECASE | re.DOTALL,
)

# Mappa giorno colonna Excel -> nome enum italiano (GiornoSettimana.name)
DAY_COL_MAP = {
    3: "lunedi",
    4: "martedi",
    5: "mercoledi",
    6: "giovedi",
    7: "venerdi",
}

# Palette colori per le zone (default sensato).
ZONE_COLOR_PALETTE = [
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
    "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
    "#F8B500", "#52B788",
]

# Default per medici il cui indirizzo inizia con "Policlinico" (es. SUN,
# Argenziano, Federico II). Per questi medici non e' specificata la zona
# nel foglio, ma sappiamo che ricadono tutti nel distretto 27.
DISTRETTO_POLICLINICO = 27         # "ZONA ARENELLA - VOMERO - RIONE ALTO"
ZONA_POLICLINICO = "Arenella"
STRUTTURA_POLICLINICO = "Policlinico"
POLICLINICO_PREFIX = "policlinico"  # case-insensitive


def _applica_logica_policlinico(
    indirizzo: Optional[str],
    struttura: Optional[str],
    zona_name: str,
    distretto_id: int,
) -> tuple[Optional[str], Optional[str], str, int]:
    """Se l'indirizzo inizia con 'Policlinico', applica i default di sede.

    Regole:
    - struttura = 'Policlinico' se non gia' valorizzata
    - zona = 'Arenella' se la zona attuale e' vuota o '(senza zona)'
    - distretto_id = 27 (Arenella-Vomero-Rione Alto)
    Altrimenti ritorna i valori invariati.
    """
    if indirizzo and indirizzo.lower().startswith(POLICLINICO_PREFIX):
        new_struttura = struttura or STRUTTURA_POLICLINICO
        new_zona = zona_name if zona_name and zona_name != "(senza zona)" else ZONA_POLICLINICO
        return (indirizzo, new_struttura, new_zona, DISTRETTO_POLICLINICO)
    return (indirizzo, struttura, zona_name, distretto_id)


def _aggiungi_fascia_fittizia(
    medico: MedicoRecord,
    indirizzi_rows: list[str],
    strutture_rows: list[str],
    zone_rows: list[str],
    current_distretto_code: Optional[int],
    zone_seen: dict[str, int],
    result: ParseResult,
) -> None:
    """Crea una fascia 00:00-00:00 domenica per conservare i dati anagrafici.

    Usata per medici che non hanno prodotto fasce reali (celle giorni vuote
    o orari non decifrabili): senza questa fascia, ASL/distretto/zona/
    struttura/indirizzo verrebbero persi. La fascia fittizia ha
    is_fittizia=True cosi' lo scheduler la salta.
    """
    indirizzo = indirizzi_rows[0].strip() if indirizzi_rows else None
    struttura = strutture_rows[0].strip() if strutture_rows else None
    zona_name = zone_rows[0].strip() if zone_rows else None
    if not zona_name:
        zona_name = "(senza zona)"

    indirizzo, struttura, zona_name, distretto_id = _applica_logica_policlinico(
        indirizzo, struttura, zona_name, current_distretto_code or 0,
    )

    # Registra la zona (potrebbe essere "Arenella" per Policlinico)
    k = zona_name.lower()
    if k not in zone_seen:
        zone_seen[k] = len(result.zone)
        result.zone.append(ZonaRecord(
            nome=zona_name, colore_hex=_assign_zone_color(len(result.zone))))

    medico.fasce.append(FasciaRecord(
        nr=0,
        minuti_inizio=0,
        minuti_fine=0,
        giorni_settimana=["domenica"],
        distretto_id=distretto_id,
        zona_id=zone_seen[k],
        struttura=struttura,
        indirizzo=indirizzo,
        is_fittizia=True,
        id_area=None,
    ))


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def _resolve_asl_code(description: str) -> Optional[int]:
    """Risolve il codice SSN reale di un'ASL dalla descrizione del foglio."""
    for pattern, code in ASL_PATTERNS:
        if pattern.search(description):
            return code
    return None


def _split_multi(value) -> list[str]:
    """Splitta un valore per \\n o |, ripulendo ogni parte.

    Restituisce lista vuota se il valore e' vuoto.
    """
    if value is None:
        return []
    text = str(value).strip()
    if not text:
        return []
    parts = re.split(r"[\n|]", text)
    return [p.strip() for p in parts if p.strip()]


def _split_lines_kept(value) -> list[str]:
    """Splitta per \\n mantenendo l'indice di riga (righe vuote incluse).

    Usata per allineare la riga N di una cella giorno-orario con la riga N
    di C2 (indirizzo) / C10 (struttura) / C11 (zona). A differenza di
    `_split_multi`, NON filtra le righe vuote perche' l'allineamento dipende
    dalla posizione.
    """
    if value is None:
        return []
    text = str(value)
    if not text.strip():
        return []
    return text.split("\n")


# Regex usata per ripulire il nome dalle keyword telefoniche residue.
PHONE_OR_KEYWORD_RE = re.compile(
    r"\+?39[\s.\-]?(?:3\d{2}|0\d{1,3})(?:[\s.]?\d+){1,5}"
    r"|\b(?:tel|cell|studio|stusdio|cell\.?|segr\.?)\b\.?",
    re.IGNORECASE,
)


def _clean_name(raw_name: str) -> str:
    """Estrae il nome del medico dalla prima riga di C1, rimuovendo telefoni."""
    text = raw_name.split("\n")[0].strip()
    # Rimuovi keyword tel/cell e numeri telefonici
    text = PHONE_OR_KEYWORD_RE.sub(" ", text)
    # Rimuovi suffissi comuni tipo "(prof)", "(moglie Brunetti)"
    text = re.sub(r"\([^)]*\)", " ", text)
    # Rimuovi punteggiatura residua e spazi multipli
    text = re.sub(r"[;:,.]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


# Pattern blacklist per la colonna note (C8)
NOTE_BLACKLIST = re.compile(
    r"^\s*(DANIELE|PA\.?|P,A,|ASL|S\.?P\.?A\.?)\s*$",
    re.IGNORECASE,
)


def _filter_note(value) -> Optional[str]:
    """Filtra la colonna note, restituendo solo le righe informative.

    Scarta: 'DANIELE', 'P.A.', 'P,A,', numeri isolati, keyword telefoniche.
    Mantiene: date ('mar 12/12/17'), testo libero.
    """
    if not value:
        return None
    text = str(value).strip()
    if not text:
        return None
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    kept: list[str] = []
    for line in lines:
        if NOTE_BLACKLIST.match(line):
            continue
        # Salta righe che sono solo numeri (telefono gia' estratto)
        if re.match(r"^\d", line):
            continue
        # Salta keyword telefoniche residue
        if re.match(r"^\s*(tel|cell|studio|stusdio|cell\.?|segr\.?)", line, re.IGNORECASE):
            continue
        kept.append(line)
    return " | ".join(kept) if kept else None


def _parse_distretto_text(text: str) -> Optional[tuple[int, str]]:
    """Parsa una riga distretto. Ritorna (codice, descrizione) o None."""
    if not text:
        return None
    m = DISTRETTO_RE.match(text.strip())
    if not m:
        return None
    codice = int(m.group(1))
    descrizione = m.group(2).strip()
    return codice, descrizione


def _assign_zone_color(zone_index: int) -> str:
    """Assegna un colore dalla palette in modo deterministico."""
    return ZONE_COLOR_PALETTE[zone_index % len(ZONE_COLOR_PALETTE)]


# ----------------------------------------------------------------------------
# Mappatura orari "sbagliati" (foglio orarisbagliati del file Excel)
# ----------------------------------------------------------------------------

# Regex per estrarre un intervallo "H,MM - H,MM" dal testo "Diventa".
# Accetta ., : o nessun separatore decimale, e trattino semplice/en-dash/em-dash.
_DIVENTA_INTERVAL_RE = re.compile(
    r"(\d{1,2})[.,:]?(\d{0,2})\s*[-–—]\s*(\d{1,2})(?:[.,:]?(\d{0,2}))?"
)


def _normalizza_chiave_mappatura(testo) -> str:
    """Chiave di match per la mappatura orarisbagliati.

    Mantiene i leading/trailing newline (significativi: '\\npomeriggio' ha un
    "Diventa" diverso da 'pomeriggio') e strippa solo gli spazi laterali di
    ogni riga interna.

    Esempi:
      'mattina'                       -> '0|mattina|0'
      '\\nmattina'                    -> '1|mattina|0'
      'mattina\\npomeriggio'          -> '0|mattina|pomeriggio|0'
      '\\npomeriggio\\nmattina'       -> '1|pomeriggio|mattina|0'
    """
    text = str(testo or "")
    n_lead = len(text) - len(text.lstrip("\n"))
    n_trail = len(text) - len(text.rstrip("\n"))
    if n_trail:
        inner = text[n_lead:-n_trail]
    else:
        inner = text[n_lead:]
    rows = [r.strip() for r in inner.split("\n")]
    return f"{n_lead}|{'|'.join(rows)}|{n_trail}"


def _parse_diventa(testo: str) -> list[tuple[int, int]]:
    """Estrae 1 o 2 intervalli orari dal testo della colonna 'Diventa'.

    Il formato atteso e' HH:MM-HH:MM, eventualmente ripetuto 2 volte separate
    da 2+ spazi (es. '10:00-12:30  16:00-20:00'). Restituisce la lista delle
    (minutiInizio, minutiFine) trovate, oppure [] se il testo non e' parsabile.
    """
    if not testo:
        return []
    result: list[tuple[int, int]] = []
    for m in _DIVENTA_INTERVAL_RE.finditer(str(testo)):
        h1 = int(m.group(1))
        m1 = int(m.group(2)) if m.group(2) else 0
        h2 = int(m.group(3))
        m2 = int(m.group(4)) if m.group(4) else 0
        if not (0 <= h1 <= 23 and 0 <= m1 <= 59 and 0 <= h2 <= 23 and 0 <= m2 <= 59):
            continue
        start = h1 * 60 + m1
        end = h2 * 60 + m2
        if end <= start:
            continue
        result.append((start, end))
    return result


def _carica_mappatura_orari(wb) -> dict[str, list[tuple[int, int]]]:
    """Carica il foglio 'orarisbagliati' come dict normalizzato.

    Ritorna {chiave_normalizzata: lista_di_fasce}. Se il foglio non esiste o
    e' vuoto, ritorna {}.

    In caso di chiavi duplicate, l'ultima vince e viene emesso un warning
    sul risultato. (L'utente puo' verificare nel foglio se serve.)
    """
    if "orarisbagliati" not in wb.sheetnames:
        return {}
    ws_map = wb["orarisbagliati"]
    result: dict[str, list[tuple[int, int]]] = {}
    duplicati: list[str] = []
    for r in range(2, ws_map.max_row + 1):
        c1 = ws_map.cell(r, 1).value
        c2 = ws_map.cell(r, 2).value
        if c1 is None or c2 is None:
            continue
        key = _normalizza_chiave_mappatura(c1)
        fasce = _parse_diventa(c2)
        if not fasce:
            # "Diventa" non parsabile: ignora e segnala silenziosamente
            # (verra' comunque catturato dai warnings dei singoli medici)
            continue
        if key in result:
            duplicati.append(f"  riga {r}: chiave duplicata {str(c1).strip()!r}")
        result[key] = fasce
    if duplicati:
        print(f"[orarisbagliati] ATTENZIONE: chiavi duplicate sovrascritte:")
        for d in duplicati:
            print(f"  {d}")
    return result


# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------

def parse_excel(
    workbook_path: str,
    specializzazione_lookup: dict[str, str],
    default_specializzazione_id: str,
    sheet_name: Optional[str] = None,
) -> ParseResult:
    """Parsa il foglio Excel e ritorna tutte le strutture dati.

    Args:
        workbook_path: percorso del file .xlsx.
        specializzazione_lookup: dict {nome_lower: id_firestore} caricato da Firebase.
        default_specializzazione_id: id della spec default (Dermatologia) per i casi anomali.
        sheet_name: nome del foglio (None = primo foglio).

    Returns:
        ParseResult con tutte le collection popolate + lista warning.
    """
    import openpyxl  # import lazy

    wb = openpyxl.load_workbook(workbook_path, data_only=True)
    ws = wb[sheet_name] if sheet_name else wb.active

    # Carica la mappatura orari "sbagliati" (foglio orarisbagliati) se presente.
    # Permette di recuperare orari scritti in forme non standard (es. "mattina",
    # "dalle 16,00", "14,30 --->") che parse_time_cell non riconosce.
    mappatura_orari = _carica_mappatura_orari(wb)

    result = ParseResult()
    zone_seen: dict[str, int] = {}  # nome_lower -> indice in result.zone

    current_asl_code: Optional[int] = None
    current_distretto_code: Optional[int] = None

    # Indici riga (1-based, parte da 3 per saltare header)
    for row_idx in range(3, ws.max_row + 1):
        c1_raw = ws.cell(row_idx, 1).value
        if c1_raw is None:
            continue
        c1 = str(c1_raw).strip()
        if not c1:
            continue

        # --------------------------------------------------------------
        # ASL
        # --------------------------------------------------------------
        if re.match(r"^\s*asl\s+", c1, re.IGNORECASE):
            asl_code = _resolve_asl_code(c1)
            if asl_code is None:
                result.warnings.append(f"R{row_idx}: ASL non riconosciuta: {c1!r}")
                continue
            descrizione = re.sub(r"\s+", " ", c1).strip()
            result.asl.append(AslRecord(codice=asl_code, descrizione=descrizione))
            current_asl_code = asl_code
            current_distretto_code = None
            continue

        # --------------------------------------------------------------
        # Distretto
        # --------------------------------------------------------------
        distretto_parsed = _parse_distretto_text(c1)
        if distretto_parsed is not None:
            codice, descrizione = distretto_parsed
            if current_asl_code is None:
                result.warnings.append(
                    f"R{row_idx}: distretto {codice} senza ASL precedente"
                )
                continue
            result.distretti.append(DistrettoRecord(
                codice=codice,
                nr_distretto=codice,
                descrizione=descrizione,
                codice_asl=current_asl_code,
            ))
            current_distretto_code = codice
            continue

        # --------------------------------------------------------------
        # Medico
        # --------------------------------------------------------------
        c2 = ws.cell(row_idx, 2).value
        c8 = ws.cell(row_idx, 8).value
        c9 = ws.cell(row_idx, 9).value
        c10 = ws.cell(row_idx, 10).value
        c11 = ws.cell(row_idx, 11).value
        c12 = ws.cell(row_idx, 12).value

        # Telefono: cerca in C1, C2, C8
        phones = extract_phones(c1, c2, c8)

        # Nome (prima riga C1 ripulita)
        nome = _clean_name(c1)
        if not nome:
            result.warnings.append(f"R{row_idx}: nome vuoto, riga saltata")
            continue

        # Specializzazione
        spec_id = default_specializzazione_id
        if c9:
            spec_text = str(c9).strip()
            # Prendi la prima specializzazione riconoscibile (split su \n o |)
            for candidate in re.split(r"[\n|]", spec_text):
                candidate_clean = candidate.strip().lower()
                # Togli parti tra parentesi tipo "(andare alle 17)"
                candidate_clean = re.sub(r"\([^)]*\)", "", candidate_clean).strip()
                if not candidate_clean:
                    continue
                if candidate_clean in specializzazione_lookup:
                    spec_id = specializzazione_lookup[candidate_clean]
                    break
            else:
                result.warnings.append(
                    f"R{row_idx}: spec {spec_text!r} non riconosciuta → default Dermatologia"
                )

        # Prodotti e annotazioni
        prodotti = str(c12).strip() if c12 else None
        if prodotti == "":
            prodotti = None
        annotazioni = _filter_note(c8)
        telefono_str = " | ".join(phones) if phones else None

        # Costruisci medico (le fasce vengono popolate subito sotto)
        medico = MedicoRecord(
            nome=nome,
            telefono=telefono_str,
            specializzazione_id=spec_id,
            prodotti=prodotti,
            annotazioni=annotazioni,
        )

        # Allineamento per riga: ogni cella giorno (C3-C7) contiene piu' righe.
        # La riga N-esima di un intervallo orario si abbina alla riga N-esima
        # di C2 (indirizzo), C10 (struttura) e C11 (zona). Righe vuote = niente
        # slot per quella riga.
        indirizzi_rows = _split_lines_kept(c2)
        strutture_rows = _split_lines_kept(c10)
        zone_rows = _split_lines_kept(c11)

        slots: list[tuple[str, int, int, Optional[str], Optional[str], str, int]] = []
        # Tracciamento per warning granulari:
        righe_non_decifrabili: list[tuple[str, str]] = []  # (giorno, testo)
        celle_giorno_vuote = 0

        for col_idx, giorno_name in DAY_COL_MAP.items():
            cell_value = ws.cell(row_idx, col_idx).value
            if cell_value is None or not str(cell_value).strip():
                celle_giorno_vuote += 1
                continue
            cell_text = str(cell_value)

            # Strategia di match a 2 livelli:
            # 1) Provo il match a livello CELLA (testo intero normalizzato)
            # 2) Altrimenti splitto per \n e provo riga per riga con:
            #    2a) parse_time_cell
            #    2b) mappatura orarisbagliati (riga singola)
            fasce_con_righe: list[tuple[int, int, int]] = []
            cell_key = _normalizza_chiave_mappatura(cell_text)
            if cell_key in mappatura_orari:
                # Riga di allineamento = n_lead (prima riga significativa)
                n_lead = int(cell_key.split("|", 1)[0])
                for mi, mf in mappatura_orari[cell_key]:
                    fasce_con_righe.append((mi, mf, n_lead))
            else:
                for row_n, line in enumerate(cell_text.split("\n")):
                    line_strip = line.strip()
                    if not line_strip:
                        continue
                    parsed = parse_time_cell(line_strip)
                    if parsed is not None:
                        mi, mf = parsed
                        fasce_con_righe.append((mi, mf, row_n))
                        continue
                    row_key = _normalizza_chiave_mappatura(line)
                    if row_key in mappatura_orari:
                        for mi, mf in mappatura_orari[row_key]:
                            fasce_con_righe.append((mi, mf, row_n))
                        continue
                    # Non parsabile e non in mappatura: warning
                    righe_non_decifrabili.append((giorno_name, line_strip))

            # Allinea ogni fascia matchata con la riga N di C2/C10/C11
            for mi, mf, row_n in fasce_con_righe:
                indirizzo = (indirizzi_rows[row_n].strip()
                             if row_n < len(indirizzi_rows) else "")
                struttura = (strutture_rows[row_n].strip()
                             if row_n < len(strutture_rows) else "")
                zona_name = (zone_rows[row_n].strip()
                             if row_n < len(zone_rows) else "")
                # Default Policlinico (SUN, Argenziano, ecc.): se l'indirizzo
                # inizia con "Policlinico", struttura/zona/distretto prendono
                # i valori standard del Policlinico SUN anche se non sono
                # specificati nel foglio.
                indirizzo, struttura, zona_name, distretto_id = _applica_logica_policlinico(
                    indirizzo or None, struttura or None,
                    zona_name or "(senza zona)",
                    current_distretto_code or 0,
                )
                slots.append((
                    giorno_name, mi, mf,
                    indirizzo, struttura, zona_name, distretto_id,
                ))

        # === Warning granulari ===
        def _fmt_non_decifrabili() -> str:
            giorni_dec = sorted({g for g, _ in righe_non_decifrabili})
            testi = [t for _, t in righe_non_decifrabili]
            return (f"giorni {giorni_dec} - testi {testi}")

        if not slots:
            if celle_giorno_vuote == 5:
                result.warnings.append(
                    f"R{row_idx}: {nome} senza orari settimanali (tutte le celle giorni vuote)"
                )
            elif righe_non_decifrabili:
                result.warnings.append(
                    f"R{row_idx}: {nome} ha {len(righe_non_decifrabili)} orari non decifrabili - {_fmt_non_decifrabili()}"
                )

            # Crea una fascia fittizia 00:00-00:00 domenica per conservare i
            # dati anagrafici (asl, distretto, zona, struttura, indirizzo) del
            # medico, anche se non ha orari reali. Lo scheduler la escludera'
            # (campo is_fittizia=True).
            _aggiungi_fascia_fittizia(
                medico, indirizzi_rows, strutture_rows, zone_rows,
                current_distretto_code, zone_seen, result,
            )
        else:
            # Registra le zone effettivamente usate in `result.zone`
            for _, _, _, _, _, zn, _ in slots:
                k = zn.lower()
                if k not in zone_seen:
                    zone_seen[k] = len(result.zone)
                    result.zone.append(ZonaRecord(
                        nome=zn, colore_hex=_assign_zone_color(len(result.zone))))

            # Merge: stessa (orario, indirizzo, struttura, zona, distretto)
            # → giorni uniti (NB: distretto e' parte della chiave per gestire
            # il caso di un medico con sedi in distretti diversi).
            merged: dict[tuple[int, int, Optional[str], Optional[str], str, int], list[str]] = {}
            for giorno_name, mi, mf, indirizzo, struttura, zn, distretto_id in slots:
                k = (mi, mf, indirizzo, struttura, zn.lower(), distretto_id)
                if giorno_name not in merged.setdefault(k, []):
                    merged[k].append(giorno_name)

            nr_counter = 0
            for (mi, mf, indirizzo, struttura, zn_lower, distretto_id), giorni in merged.items():
                medico.fasce.append(FasciaRecord(
                    nr=nr_counter,
                    minuti_inizio=mi,
                    minuti_fine=mf,
                    giorni_settimana=giorni,
                    distretto_id=distretto_id,
                    zona_id=zone_seen[zn_lower],  # placeholder, verra' risolto dopo insert zone
                    struttura=struttura,
                    indirizzo=indirizzo,
                    id_area=None,
                ))
                nr_counter += 1

            # Warning parziale: medico importato ma con righe non decifrate
            if righe_non_decifrabili:
                result.warnings.append(
                    f"R{row_idx}: {nome} importato con {len(righe_non_decifrabili)} orari non decifrabili - {_fmt_non_decifrabili()}"
                )

        result.medici.append(medico)

    return result


# ----------------------------------------------------------------------------
# Test isolato
# ----------------------------------------------------------------------------

if __name__ == "__main__":
    # Per testare senza Firebase: dizionario fittizio + id default fittizio.
    fake_specs = {
        "dermatologia": "fake_spec_id_derm",
        "medicina generale": "fake_spec_id_mg",
    }
    result = parse_excel(
        "../Elenco dottori 2025.xlsx",
        specializzazione_lookup=fake_specs,
        default_specializzazione_id="fake_spec_id_derm",
    )
    print(f"ASL: {len(result.asl)}")
    for a in result.asl:
        print(f"  - {a.codice}: {a.descrizione}")
    print(f"Distretti: {len(result.distretti)}")
    print(f"Zone: {len(result.zone)}")
    print(f"Medici: {len(result.medici)}")
    print(f"Totale fasce: {sum(len(m.fasce) for m in result.medici)}")
    print(f"Warning ({len(result.warnings)}):")
    for w in result.warnings[:20]:
        print(f"  - {w}")
    if len(result.warnings) > 20:
        print(f"  ... e altri {len(result.warnings) - 20}")

    # Stampa i primi 3 medici
    print("\nPrimi 3 medici:")
    for m in result.medici[:3]:
        print(f"\n  Nome: {m.nome}")
        print(f"  Tel: {m.telefono}")
        print(f"  SpecID: {m.specializzazione_id}")
        print(f"  Fasce: {len(m.fasce)}")
        for f in m.fasce[:3]:
            print(f"    - nr={f.nr} {f.giorni_settimana} {f.minuti_inizio}-{f.minuti_fine} addr={f.indirizzo!r} zona={f.zona_id}")
