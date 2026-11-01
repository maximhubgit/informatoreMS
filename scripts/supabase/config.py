"""Configurazione condivisa dagli script Supabase.

Legge i parametri da `scripts/supabase/.env` (oppure dalle variabili
d'ambiente, che hanno la precedenza se il file manca).
"""
from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv

import psycopg

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

SUPABASE_DB_URL = (os.getenv("SUPABASE_DB_URL") or "").strip()
FIREBASE_CREDENTIAL_PATH = (
    os.getenv("FIREBASE_CREDENTIAL_PATH") or "../serviceAccountKey.json"
).strip()
FIREBASE_PROJECT_ID = (
    os.getenv("FIREBASE_PROJECT_ID") or "informatorems-784a1"
).strip()


def describe_db_url(url: str) -> str:
    """Restituisce host/porta/database senza mai stampare la password."""
    try:
        parsed = urlparse(url)
        host = parsed.hostname or "?"
        port = parsed.port or 5432
        db = (parsed.path or "/").lstrip("/") or "?"
        user = parsed.username or "?"
        return f"{user}@{host}:{port}/{db}"
    except Exception:
        return "(url non valido)"


def get_connection() -> psycopg.Connection:
    """Apre una connessione Postgres verso Supabase (Session pooler)."""
    if not SUPABASE_DB_URL:
        raise SystemExit(
            "SUPABASE_DB_URL mancante.\n"
            "Copia scripts/supabase/.env.example in scripts/supabase/.env e "
            "incolla la connection string da Supabase -> Connect -> Session pooler."
        )

    kwargs = {
        "connect_timeout": 15,
        # Evita prepared statement server-side: compatibile anche con pooler.
        "prepare_threshold": None,
    }
    if "sslmode=" not in SUPABASE_DB_URL:
        kwargs["sslmode"] = "require"

    return psycopg.connect(SUPABASE_DB_URL, **kwargs)
