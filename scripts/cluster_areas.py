"""Raggruppa gli indirizzi in aree di ~3 km e aggiunge le colonne
codArea e nomeArea.

Legge:    export_informatorems_geocodificato.xlsx  (prodotto da geocode_excel.py)
Scrive:   export_informatorems_aree.xlsx

Perché NON si usa DBSCAN
------------------------
DBSCAN crea "catene": basta che ogni punto sia entro `eps` dal successivo
per unirli tutti (A 2km->B 2km->C 2km->D 2km->E diventerebbe UN gruppo di 8 km).
Qui si usa invece il clustering a LINK COMPLETO (complete-linkage): due gruppi
si fondono SOLO se la distanza MASSIMA tra qualunque coppia dei loro membri è
<= soglia. Così A ed E (6,7 km) non possono mai finire nello stesso gruppo.

Ogni riga geolocalizzata riceve:
- codArea  : numero progressivo dell'area
- nomeArea : concatenazione dei nomi Zona presenti nell'area (senza ripetizioni)
- OrdinePercorso : ordine consigliato di visita (parte dal primo indirizzo e
  va sempre al più vicino non ancora visitato) — utile per la pianificazione
  giornaliera del tragitto.
- DistKmCumulativa : km cumulati lungo l'OrdinePercorso.

Le righe NON geolocalizzate (lat = -100) restano isolate, ognuna nella propria
area, così non inquinano i gruppi e restano facili da sistemare a mano.
"""
from __future__ import annotations

import os
import sys
from math import radians

import numpy as np
import pandas as pd
from sklearn.cluster import AgglomerativeClustering

from excel_format import write_formatted_excel

# Output UTF-8 anche su file (Windows usa cp1252)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "export_informatorems_geocodificato.xlsx")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "export_informatorems_aree.xlsx")

SENTINEL = -100.0
LAT_COL = "Latitudine"
LON_COL = "Longitudine"
ZONA_COL = "Zona"

# Raggio massimo dell'area (raggio, non diametro): ogni indirizzo del gruppo
# dista al massimo ~AREA_KM da tutti gli altri del gruppo.
AREA_KM = 3.0


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distanza in km tra due coordinate (formula haversine)."""
    R = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = (np.sin(dlat / 2) ** 2
         + np.cos(radians(lat1)) * np.cos(radians(lat2)) * np.sin(dlon / 2) ** 2)
    return float(R * 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a)))


def distance_matrix(coords: np.ndarray) -> np.ndarray:
    n = len(coords)
    m = np.zeros((n, n))
    for i in range(n):
        for j in range(i + 1, n):
            d = haversine(coords[i, 0], coords[i, 1],
                          coords[j, 0], coords[j, 1])
            m[i, j] = m[j, i] = d
    return m


def cluster_geo(coords: np.ndarray, area_km: float) -> np.ndarray:
    """Cluster con complete-linkage, tagliato a `area_km` (anti-chaining)."""
    if len(coords) == 1:
        return np.array([0])
    dm = distance_matrix(coords)
    model = AgglomerativeClustering(
        n_clusters=None,
        distance_threshold=area_km,
        linkage="complete",
        metric="precomputed",
    )
    return model.fit_predict(dm)


def greedy_tour(coords: np.ndarray, start: int = 0):
    """Ordine di visita: dal punto di partenza va sempre al più vicino non
    visitato. Restituisce (indici_ordinati, distanze_cumulate_km)."""
    n = len(coords)
    visited = [False] * n
    order = [start]
    visited[start] = True
    cum = [0.0]
    cur = start
    while len(order) < n:
        best_idx, best_d = None, float("inf")
        for j in range(n):
            if not visited[j]:
                d = haversine(coords[cur, 0], coords[cur, 1],
                              coords[j, 0], coords[j, 1])
                if d < best_d:
                    best_d, best_idx = d, j
        visited[best_idx] = True
        order.append(best_idx)
        cum.append(cum[-1] + best_d)
        cur = best_idx
    return order, cum


def main() -> int:
    print("=" * 70)
    print("RAGGRUPPAMENTO AREE ~3 km (complete-linkage, anti-chaining)")
    print("=" * 70)

    df = pd.read_excel(INPUT_FILE)
    df[LAT_COL] = pd.to_numeric(df[LAT_COL], errors="coerce")
    df[LON_COL] = pd.to_numeric(df[LON_COL], errors="coerce")
    df.loc[df[LAT_COL].isna(), LAT_COL] = SENTINEL
    df.loc[df[LON_COL].isna(), LON_COL] = SENTINEL

    geo_mask = (df[LAT_COL] != SENTINEL) & (df[LON_COL] != SENTINEL)
    geo_idx = np.where(geo_mask)[0]
    excl_idx = np.where(~geo_mask)[0]

    print(f"Righe con dati: {len(df)} | geolocalizzate: {len(geo_idx)} | "
          f"senza coordinate (-100): {len(excl_idx)}")

    coords = df.loc[geo_idx, [LAT_COL, LON_COL]].to_numpy(dtype=float)
    labels = cluster_geo(coords, AREA_KM)

    cod_area = np.empty(len(df), dtype=int)
    cod_area[excl_idx] = -1  # temporaneo per le righe senza coordinate

    # Numera le aree in ordine di prima comparsa (per riga nel file)
    seen = {}
    for pos, lab in zip(geo_idx, labels):
        if lab not in seen:
            seen[lab] = len(seen) + 1
        cod_area[pos] = seen[lab]

    # nomi zona distinti per area (in ordine di comparsa, senza ripetizioni)
    nome_area = {}
    for pos in geo_idx:
        area = cod_area[pos]
        z = df.at[pos, ZONA_COL]
        nome = "" if pd.isna(z) else str(z).strip()
        nome_area.setdefault(area, [])
        if nome and nome not in nome_area[area] and nome != "(senza zona)":
            nome_area[area].append(nome)

    df["codArea"] = cod_area
    df["NomeArea"] = df["codArea"].map(
        lambda a: " - ".join(nome_area.get(a, [])) if a > 0 else "NON GEOLOCALIZZATO"
    )

    # Ordine di percorso + distanza cumulativa dentro ogni area
    ordine = np.empty(len(df), dtype=float)  # float per poter mettere nan
    dist_cum = np.empty(len(df), dtype=float)
    ordine[:] = np.nan
    dist_cum[:] = np.nan

    # raggruppa gli indici per area (numerate) per calcolare il tour
    areas_ordered = {}
    for pos, area in zip(geo_idx, cod_area[geo_idx]):
        areas_ordered.setdefault(area, []).append(pos)

    for area, positions in areas_ordered.items():
        positions = sorted(positions)
        acoords = coords[[list(geo_idx).index(p) for p in positions]]
        order, cum = greedy_tour(acoords, start=0)
        for k, p in enumerate(positions):
            ordine[p] = order.index(k) + 1 if k in order else k + 1
        # ordina: mappa riga-posizione -> passo
        passo = {p: i + 1 for i, p in enumerate([positions[o] for o in order])}
        for p in positions:
            ordine[p] = passo[p]
            # distanza cumulativa per quel passo
            dist_cum[p] = cum[passo[p] - 1]

    df["OrdinePercorso"] = ordine
    df["DistKmCumulativa"] = dist_cum

    # Riordina colonne: metti le nuove in coda
    base = [c for c in df.columns if c not in
            ("codArea", "NomeArea", "OrdinePercorso", "DistKmCumulativa")]
    extra = [c for c in df.columns if c not in base]
    df = df[base + extra]

    # Ordinamento finale per codArea, poi OrdinePercorso
    df = df.sort_values(["codArea", "OrdinePercorso"], na_position="last")
    df = df.reset_index(drop=True)

    write_formatted_excel(
        df,
        OUTPUT_FILE,
        km_cols=("DistKmCumulativa",),
        decimal_cols=(LAT_COL, LON_COL),
        red_cols=(LAT_COL, LON_COL),
        red_value=SENTINEL,
        area_col="codArea",
    )

    # Riepilogo
    n_aree = df[df["codArea"] > 0]["codArea"].nunique()
    print(f"\nAree create: {n_aree} (righe geolocalizzate) "
          f"+ {len(excl_idx)} righe non geolocalizzate singole")
    print("\nDettaglio aree:")
    for a, grp in df[df["codArea"] > 0].groupby("codArea"):
        c = grp[[LAT_COL, LON_COL]].to_numpy(dtype=float)
        if len(c) > 1:
            diam = max(haversine(c[i, 0], c[i, 1], c[j, 0], c[j, 1])
                       for i in range(len(c)) for j in range(i + 1, len(c)))
        else:
            diam = 0.0
        print(f"  Area {int(a):2d} | {len(grp):3d} indirizzi | diametro max "
              f"{diam:4.1f} km | {grp['NomeArea'].iloc[0]}")

    if len(excl_idx) > 0:
        print(f"\nAttenzione: {len(excl_idx)} righe con lat=-100 (non geolocalizzate) "
              f"sono state lasciate fuori dai gruppi.")

    print(f"\nFile salvato: {OUTPUT_FILE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
