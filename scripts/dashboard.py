"""Dashboard informatorems - Streamlit"""
import streamlit as st
import pandas as pd
import MySQLdb
import MySQLdb.cursors

# ── Configurazione DB ──────────────────────────────────
DB_CONFIG = {
    "host": "192.168.1.242",
    "user": "root",
    "passwd": "Assistenza2019@",
    "db": "teamold",
    "charset": "utf8mb4",
    "cursorclass": MySQLdb.cursors.DictCursor,
    "connect_timeout": 10,
}


# ── Connessione e query ─────────────────────────────────
@st.cache_resource
def get_connection():
    return MySQLdb.connect(**DB_CONFIG)


def query_count(table: str) -> int:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
            row = cur.fetchone()
            return row["cnt"] if row else 0
    except MySQLdb.OperationalError as e:
        st.error(f"Errore di connessione al DB per la tabella `{table}`: {e}")
        return 0


def query_artmaster(limit: int = 100) -> pd.DataFrame:
    conn = get_connection()
    try:
        df = pd.read_sql(
            f"SELECT art_codart, art_descart, art_stagione FROM artmaster LIMIT {limit}",
            conn,
        )
    except MySQLdb.OperationalError as e:
        st.error(f"Errore di connessione al DB per artmaster: {e}")
        return pd.DataFrame()
    return df


# ── App ─────────────────────────────────────────────────
st.set_page_config(page_title="Dashboard Informatorems", layout="wide")
st.title("Dashboard Informatorems")

# Carica dati
total_movmag = query_count("movmag")
total_anagclifor = query_count("anagclifor")
df_artmaster = query_artmaster(100)

# ── Card centrali ───────────────────────────────────────
col1, col2, col3 = st.columns([1, 2, 1])

with col1:
    pass  # spazio vuoto a sinistra

# Card verde - Totali MovMag
st.markdown(
    """
    <div style="
        background: white;
        border-left: 6px solid #2E7D32;
        border-radius: 10px;
        padding: 20px 24px;
        margin: 8px auto;
        box-shadow: 0 2px 8px rgba(0,0,0,0.12);
        max-width: 400px;
        text-align: center;
    ">
        <p style="color: #2E7D32; font-size: 14px; margin: 0 0 4px 0;
                    text-transform: uppercase; letter-spacing: 1px;">
            Totali MovMag
        </p>
        <p style="font-size: 36px; font-weight: bold; color: #2E7D32; margin: 4px 0;">
    """
    + f"{total_movmag:,}".replace(",", ".")
    + """
        </p>
    </div>
    """,
    unsafe_allow_html=True,
)

# Card gialla - Totali AnagCliFor
st.markdown(
    """
    <div style="
        background: white;
        border-left: 6px solid #F9A825;
        border-radius: 10px;
        padding: 20px 24px;
        margin: 8px auto;
        box-shadow: 0 2px 8px rgba(0,0,0,0.12);
        max-width: 400px;
        text-align: center;
    ">
        <p style="color: #F9A825; font-size: 14px; margin: 0 0 4px 0;
                    text-transform: uppercase; letter-spacing: 1px;">
            Totali AnagCliFor
        </p>
        <p style="font-size: 36px; font-weight: bold; color: #F9A825; margin: 4px 0;">
    """
    + f"{total_anagclifor:,}".replace(",", ".")
    + """
        </p>
    </div>
    """,
    unsafe_allow_html=True,
)

with col3:
    pass  # spazio vuoto a destra

# ── Spaziatura ──────────────────────────────────────────
st.markdown("---")

# ── Griglia artmaster ───────────────────────────────────
st.subheader("Artmaster (primi 100 record)")

if df_artmaster.empty:
    st.warning("Nessun record trovato nella tabella artmaster.")
else:
    st.dataframe(
        df_artmaster,
        use_container_width=True,
        hide_index=True,
        column_config={
            "art_codart": st.column_config.TextColumn(
                "Codice Articolo", width="small"
            ),
            "art_descart": st.column_config.TextColumn(
                "Descrizione", width="large"
            ),
            "art_stagione": st.column_config.TextColumn(
                "Stagione", width="small"
            ),
        },
    )
    st.caption(
        f"Mostrate {len(df_artmaster)} righe su un totale di "
        f"{query_count('artmaster'):,} record."
    )
