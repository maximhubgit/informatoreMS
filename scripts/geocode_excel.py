"""Geocode le righe di export_informatorems.xlsx aggiungendo le colonne
Latitudine e Longitudine.

Strategia:
- Ogni riga viene geocodificata a partire dalla colonna Indirizzo.
- Se l'Indirizzo è incompleto o poco informativo, si usa anche Zona e
  Distretto per costruire una query più precisa (nome città).
- Alcuni Indirizzi sono nomi di ospedali: vengono mappati su un indirizzo
  reale tramite HOSPITAL_MAP (query case-insensitive).
- Per disambiguare gli indirizzi generici ("Via Roma", "Piazza Nazionale"...)
  la ricerca Nominatim viene vincolata con un viewbox sulla regione
  Napoli/Caserta e con il nome della città ricavato dal Distretto.

Output: export_informatorems_geocodificato.xlsx  (stessa struttura + colonne)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Optional

# Output UTF-8 anche quando stdout viene reindirizzato su file (Windows usa cp1252)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter

from excel_format import write_formatted_excel

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "export_informatorems.xlsx")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "export_informatorems_geocodificato.xlsx")
CACHE_FILE = os.path.join(SCRIPT_DIR, "geocode_cache.json")

# Valore sentinella per coordinate non geolocalizzate
SENTINEL = -100.0

# Viewbox di disambiguazione: regione Napoli/Caserta.
# Formato geopy: coppia di punti [[lat1, lon1], [lat2, lon2]].
# Copre grosso modo lat 40.7-41.3, lon 14.0-14.7.
VIEWBOX = [[40.70, 14.00], [41.30, 14.70]]

# Nomi di ospedali presenti nella colonna Indirizzo -> indirizzo reale completo.
# Il match è case-insensitive e per parola esatta (così "Via Annunziata" non
# viene confusa con l'ospedale "Annunziata").
HOSPITAL_MAP = {
    "annunziata": "Via Egiziaca a Forcella, 18, 80139 Napoli (NA)",
    "santobono": "Via Mario Fiore, 6, 80129 Napoli",
    "pausilipon": "Via Posillipo, 226, 80123 Napoli (NA)",
    "pausillipon": "Via Posillipo, 226, 80123 Napoli (NA)",  # variante ortografica
}

# Colonne che andiamo a usare per costruire la query
ADDR_COL = "Indirizzo"
ZONA_COL = "Zona"
DISTRETTO_COL = "Distretto"

DATA_COLS = [
    "IdFascia", "Nr", "IdMedico", "ASL", "Distretto", "NrDistretto",
    "Medico", "Specializzazione", "Indirizzo", "Struttura", "Zona", "Giorno",
    "OrarioInizio", "OrarioFine", "Telefono", "Prodotti", "Annotazioni",
]


def _norm(s: object) -> str:
    """Normalizza una stringa per confronti case-insensitive."""
    if s is None or (isinstance(s, float) and pd.isna(s)):
        return ""
    return " ".join(str(s).lower().replace(",", " ").split())


def hospital_address(indirizzo: object) -> Optional[str]:
    """Se l'Indirizzo è un nome di ospedale, restituisce l'indirizzo reale."""
    if indirizzo is None:
        return None
    norm = _norm(indirizzo)
    # match solo se la cella è ESATTAMENTE il nome dell'ospedale (niente numeri civici)
    for name, addr in HOSPITAL_MAP.items():
        if norm == name or norm == name + ".":
            return addr
    return None


# Parole chiave che indicano l'inizio del vero indirizzo stradale
STREET_KEYWORDS = (
    "via ", "viale ", "corso ", "piazza ", "largo ", "salita ",
    "traversa ", "calata ", "vico ", "strada ", "v.le ", "p.sse ",
)

# Correzioni di errori di battitura trovati nella colonna Zona
ZONA_TYPO = {
    "chiai a ?": "Chiaia",
    "chiaia ?": "Chiaia",
    "maddalloni": "Maddaloni",
    "pollenatrocchia": "Pollena Trocchia",
    "s. m. capua vetere": "Santa Maria Capua Vetere",
}

# Correzioni per errori di battitura nell'indirizzo (lettere mancanti o errate)
ADDR_TYPO = {
    "egiziaca": "Egiziaca",
    "forcella": "Forcella",
    "forcella,": "Forcella,",
    "forcella, 18": "Forcella, 18",
    "pansini": "Pansini",
    "pansini 5": "Pansini 5",
    "santa maria": "Santa Maria",
    "santa mari a": "Santa Maria",
    "santa mari della libertà": "Santa Maria della Libertà",
    "liberta": "Libertà",
    "forcella": "Forcella",
    "forcella,": "Forcella,",
    "egiziaca a": "Egiziaca a",
    "egiziaca a Forcella": "Egiziaca a Forcella",
    "via egiziaca": "Via Egiziaca",
    "via egiziaca a Forcella": "Via Egiziaca a Forcella",
    "forcella, 18": "Forcella, 18",
    "s. m. capua vetere": "Santa Maria Capua Vetere",
    "pausilipon": "Pausilipon",
    "pausillipon": "Pausilipon",
    "pausilipon": "Pausilipon",
    "annunziata": "Annunziata",
    "annunziata 18": "Annunziata 18",
    "annunziata,": "Annunziata,",
    "campanella": "Campanella",
    "campanella 9": "Campanella 9",
    "campanella,": "Campanella,",
    "via campanella": "Via Campanella",
    "stafetta": "Stafetta",
    "stafetta 125": "Stafetta 125",
    "stafetta,": "Stafetta,",
    "via stafetta": "Via Stafetta",
    "terracciano": "Terracciano",
    "davide winspeare": "Davide Winspeare",
    "via terracciano": "Via Terracciano",
    "via davide winspeare": "Via Davide Winspeare",
    "barger": "Barger",
    "via della libertà": "Via della Libertà",
    "via della libertà": "Via della Libertà",
    "la libertà": "La Libertà",
}

# Mappatura dei correttori di encoding per caratteri mojibake (cp1252 → UTF-8)
# I caratteri più comuni in indirizzi italiani che risultano mojibake:
# → → é è ì ì À À Ç ä ì é è ì Ĭ Ī à à ç ä à é è ì
ENCODING_FIXES = {
    "santa maria della libertà": "Santa Maria della Libertà",
    "s. m. capua vetere": "Santa Maria Capua Vetere",
    "liberta": "Libertà",
    "forcella": "Forcella",
    "egiziaca": "Egiziaca",
    "pausilipon": "Pausilipon",
    "annunziata": "Annunziata",
    "pansini": "Pansini",
    "terracciano": "Terracciano",
    "stafetta": "Stafetta",
    "campanella": "Campanella",
    "via egiziaca": "Via Egiziaca",
    "via santamaria": "Via Santa Maria",
    "via della libertà": "Via della Libertà",
    "via campanella": "Via Campanella",
    "via stafetta": "Via Stafetta",
}


def _fix_encoding(s: str) -> str:
    """Corregge errori di encoding (caratteri mojibake) nell'indirizzo.

    Il problema tipico è che i caratteri cp1252 (es. á, è, ì) vengono interpretati
    come altro e distorcono la ricerca Nominatim. Questa funzione tenta di
    ripristinare i caratteri corretti sostituendo pattern noti con le correzioni.
    """
    if not s:
        return s
    s = str(s)
    # Correzioni per caratteri mojibake (cp1252 → UTF-8)
    for bad, good in ENCODING_FIXES.items():
        if bad in s:
            s = s.replace(bad, good)
    return s


# Mappa degli indirizzi con errore di comune (comune sbagliato, ma corretto
# sempre tra Napoli e Caserta) e corrispondenza completa.
# Usata come fallback quando Nominatim restituisce un comune errato.
# Le chiavi sono le query Nominatim generate con il comune sbagliato;
# i valori sono gli indirizzi completi e corretti.
ADDRESS_MAP = {
    # comune sbagliato → comune corretto (Napoli)
    "via campanella 9, Napoli": "Via Campanella 9, Napoli, 80100 Caserta",
    "via stafetta 125, Napoli": "Via Stafetta 125, Napoli, 80050 Napoli",
    "via terracciano 11, Napoli": "Via Terracciano 11, Napoli, 80050 Napoli",
    "via davide winspeare 10, Napoli": "Via Davide Winspeare 10, Napoli, 80050 Napoli",
    # comune sbagliato → comune corretto (Caserta)
    "via campanella 9, Caserta": "Via Campanella 9, Caserta, 81043 Caserta",
    "via stafetta 125, Caserta": "Via Stafetta 125, Caserta, 81043 Caserta",
    "via terracciano 11, Caserta": "Via Terracciano 11, Caserta, 81043 Caserta",
    "via davide winspeare 10, Caserta": "Via Davide Winspeare 10, Caserta, 81043 Caserta",
    # comune sbagliato → comune corretto (Aversa)
    "via campanella 9, Aversa": "Via Campanella 9, Aversa, 81040 Aversa",
    "via stafetta 125, Aversa": "Via Stafetta 125, Aversa, 81040 Aversa",
    # comune sbagliato → comune corretto (Caserta)
    "via campanella 9, Santa Maria Capua Vetere": "Via Campanella 9, Santa Maria Capua Vetere, 81040 Caserta",
    # typo di comune
    "via egiziaca 18, caserta": "Via Egiziaca 18, Caserta, 81040 Caserta",
    "via egiziaca 18, napoli": "Via Egiziaca 18, Napoli, 80139 Napoli",
    # correzioni per "santa maria della libertà" (mojibake)
    "via santamaria della libertà": "Via Santa Maria della Libertà, Napoli, 80100 Napoli",
    "via santamaria della libertà, caserta": "Via Santa Maria della Libertà, Caserta, 81040 Caserta",
    "via santa maria della libertà": "Via Santa Maria della Libertà, Napoli, 80100 Napoli",
    # correzioni per caratteri mojibake nell'indirizzo
    "via santamaria della libertà 24 f": "Via Santa Maria della Libertà 24 F, Napoli, 80100 Napoli",
}


def _clean_address(indirizzo: object) -> str:
    """Pulisce l'Indirizzo: toglie note tra parentesi e prefissi del nome
    della struttura ("Policlinico (SUN) VIA Pansini 5" -> "via pansini 5")."""
    s = _norm(indirizzo or "")
    if not s:
        return ""
    # rimuove gruppo tra parentesi (es. "(SUN)", "(Policlinico)", "(Studio X)")
    s = re.sub(r"\([^)]*\)", " ", s)
    # se resta una parentesi non chiusa, taglia tutto da lì in poi (es.
    # "...120(difronte agriturismo "La Vigna")
    if "(" in s:
        s = s.split("(", 1)[0]
    s = re.sub(r"[\"']", " ", s)  # virgolette pendenti
    s = re.sub(r"\s+$", "", s)  # spazi finali
    s = " ".join(s.split())
    # taglia tutto ciò che precede la prima parola-classe stradale
    idxs = [s.find(k) for k in STREET_KEYWORDS]
    idxs = [i for i in idxs if i >= 0]
    if idxs:
        j = min(idxs)
        if j > 0:
            s = s[j:]
    s = s.strip()
    # Correzione errori di encoding (caratteri mojibake)
    s = _fix_encoding(s)
    return s


def city_from_distretto(distretto: object) -> str:
    """Ricava il nome città principale dal Distretto.

    - "ZONA ..." -> Napoli (sono quartieri/zone di Napoli)
    - "Aversa\\nAVERSA" -> Aversa
    - "CASERTA\\n..." -> Caserta
    - "FRATTAMAGGIORE - ..." -> Frattamaggiore
    - "PORTICI - TORRE DEL GRECO" -> Portici (primo elemento)
    """
    if distretto is None:
        return ""
    text = str(distretto).strip()
    if not text:
        return ""
    if text.upper().startswith("ZONA"):
        return "Napoli"
    # prende la prima riga, poi il primo elemento prima di " - "
    first_line = text.splitlines()[0].strip()
    city = first_line.split(" - ")[0].strip()
    return city.title() if city else ""


def build_query(indirizzo: object, zona: object, distretto: object) -> str:
    """Costruisce la stringa di query per Nominatim.

    Priorità (come richiesto): Indirizzo -> Zona -> Distretto.
    La Zona (se è un luogo riconoscibile) prevale sul nome città ricavato
    dal Distretto, per evitare contraddizioni (es. zona "Grumo Nevano"
    dentro un distretto che inizia con "Frattamaggiore").
    """
    # 1) Se è un ospedale noto, usa l'indirizzo reale già completo
    hospital = hospital_address(indirizzo)
    if hospital:
        return hospital

    address = _clean_address(indirizzo)

    zona_norm = _norm(zona).strip(" ?")
    if zona_norm in ("", "(senza zona)", "senza zona", "napoletano"):
        zona_norm = ""
    zona_norm = ZONA_TYPO.get(zona_norm, zona_norm)

    city = city_from_distretto(distretto)

    # Luogo: preferisce la Zona; se la Zona è assente usa la città dal distretto.
    if zona_norm:
        place = zona_norm.title()
        # Se la Zona è un quartiere di Napoli (distretto "ZONA ..."),
        # aggiungi "Napoli" per disambiguare la via.
        if city and city == "Napoli" and zona_norm.lower() != "napoli":
            place = f"{place}, Napoli"
    else:
        place = city if city else ""

    parts = [address] if address else []
    if place:
        parts.append(place)
    return ", ".join(parts)


def load_cache() -> dict:
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_cache(cache: dict) -> None:
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except OSError as e:
        print(f"      (cache non salvata: {e})")


def geocode_factory():
    geolocator = Nominatim(user_agent="informatorems-geocode")
    rate_limited = RateLimiter(geolocator.geocode, min_delay_seconds=1.1)

    def _geocode(query: str):
        try:
            return rate_limited(
                query,
                viewbox=VIEWBOX,
                bounded=False,
                country_codes="it",
                language="it",
                limit=5,
            )
        except Exception as e:
            print(f"      ERRORE geocoding '{query}': {e}")
            return None

    return _geocode


def _geocode_with_retry(geocode_fn, query: str) -> Optional[str]:
    """Tenta di geocodificare una query usando la funzione di geocoding
    fornita, provando versioni alternative in caso di fallimento.

    Priorità:
    1. La query originale
    2. La stessa query ma con il comune corretto (dalla ADDRESS_MAP)
    3. Prova senza il nome della zona (usa solo via + numero)
    4. Prova forzando "Napoli" come città (se il distretto
       derivato fornisce un comune sbagliato)

    Restituisce il risultato del geocoding se trovato, oppure
    None se nessuna versione è stata trovata.
    """
    # 1) Prova la query originale
    result = geocode_fn(query)
    if result is not None:
        return result

    # 2) Prova con il comune corretto, se l'ADDRESS_MAP lo contiene
    if query in ADDRESS_MAP:
        result = geocode_fn(ADDRESS_MAP[query])
        if result is not None:
            return result

    # 3) Prova senza il nome della zona (usa solo via + numero)
    parts = query.split(",")
    if len(parts) >= 2:
        simplified = parts[0].strip()
        result = geocode_fn(simplified)
        if result is not None:
            return result

    # 4) Prova forzando "Napoli" come città
    if "napoli" in query.lower():
        alt_query = query
        if "Napoli" not in alt_query and "Caserta" not in alt_query:
            alt_query = f"{query}, Napoli"
        result = geocode_fn(alt_query)
        if result is not None:
            return result

    return None


def main() -> int:
    print("=" * 70)
    print("GEOCODING EXCEL → latitudine/longitudine")
    print("=" * 70)

    df = pd.read_excel(INPUT_FILE)
    data = df.dropna(subset=DATA_COLS, how="all").copy()
    print(f"Righe con dati: {len(data)}")

    cache = load_cache()
    geocode = geocode_factory()

    new_cache: dict = {}
    lats: list[float] = []
    lons: list[float] = []
    queries: list[str] = []

    for idx, row in data.iterrows():
        query = build_query(row.get(ADDR_COL), row.get(ZONA_COL), row.get(DISTRETTO_COL))
        queries.append(query)

        # Cache: la voce è utilizzabile SOLO se ha coordinate valide.
        # Voci vecchie con lat=None (fallimenti di versioni precedenti con
        # bug) vengono scartate e ricalcolate.
        hit = cache.get(query)
        if hit is not None and hit.get("lat") is not None \
                and hit["lat"] != SENTINEL:
            new_cache[query] = hit
            lats.append(hit["lat"])
            lons.append(hit["lon"])
            continue

        # Prova la query originale; se fallisce, prova alternative
        # (comune corretto, Napoli forzato, senza zona, etc.)
        loc = _geocode_with_retry(geocode, query)
        if loc is None and query in ADDRESS_MAP:
            # Fallback: l'indirizzo è già completo ma il comune è sbagliato.
            # Prova a geocodificare con l'indirizzo corretto.
            loc = geocode(ADDRESS_MAP[query])
        if loc is not None:
            entry = {"lat": loc.latitude, "lon": loc.longitude,
                     "display": loc.address}
        else:
            # Coordinate non trovate -> sentinella -100 (lat e lon)
            entry = {"lat": SENTINEL, "lon": SENTINEL, "display": None}
        new_cache[query] = entry
        cache[query] = entry
        lats.append(entry["lat"])
        lons.append(entry["lon"])

        status = f"{loc.latitude:.5f},{loc.longitude:.5f}" if loc else "NON TROVATO"
        print(f"  [{len(lats):3d}/{len(data)}] {query[:60]:60s} -> {status}")

    data["Latitudine"] = lats
    data["Longitudine"] = lons
    data["QueryGeocoding"] = queries

    matched = sum(1 for x, y in zip(lats, lons) if x != SENTINEL and y != SENTINEL)
    print(f"\nGeocodificati con successo: {matched}/{len(data)} "
          f"(non trovati: {len(data) - matched})")

    # Riordina le colonne: le nuove finiscono in coda (dopo Annotazioni)
    base = [c for c in df.columns if c in data.columns]
    extra = [c for c in data.columns if c not in df.columns]
    data = data[base + extra]

    write_formatted_excel(
        data,
        OUTPUT_FILE,
        decimal_cols=("Latitudine", "Longitudine"),
        red_cols=("Latitudine", "Longitudine"),
        red_value=SENTINEL,
    )
    save_cache(new_cache)
    print(f"File salvato (header fissato): {OUTPUT_FILE}")

    # Righe non trovate (per controllo manuale) -> lat = -100
    missing = data[data["Latitudine"] == SENTINEL]
    if not missing.empty:
        print(f"\nIndirizzi NON trovati ({len(missing)}):")
        for _, r in missing.iterrows():
            print(f"  - [{r.get('QueryGeocoding')}] "
                  f"(zona='{r.get(ZONA_COL)}', distretto='{r.get(DISTRETTO_COL)}')")
    return 0


# ============================================================================
# Modalità TEST: senza geocoding, mostra solo le query che verrebbero inviate
# ============================================================================
def dry_run() -> int:
    df = pd.read_excel(INPUT_FILE)
    data = df.dropna(subset=DATA_COLS, how="all")
    for _, row in data.iterrows():
        q = build_query(row.get(ADDR_COL), row.get(ZONA_COL), row.get(DISTRETTO_COL))
        print(q)
    return 0


if __name__ == "__main__":
    import sys
    if "--dry-run" in sys.argv:
        sys.exit(dry_run())
    sys.exit(main())
