"""Client Firebase Firestore per gli script di import/export.

Funzionalita':
- inizializzazione lazy con service account key
- wipe collection (in ordine FK-safe)
- inserimento batch (rispetta il limite Firestore di 500 ops/batch)
- lettura collection intera
- mapping tra record Python e documenti Firestore
"""
from __future__ import annotations

import json
import os
from typing import Any, Iterable, Optional

from excel_parser import AslRecord, DistrettoRecord, FasciaRecord, MedicoRecord, ZonaRecord


SERVICE_ACCOUNT_ENV = "GOOGLE_APPLICATION_CREDENTIALS"
DEFAULT_SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"
PROJECT_ID = "informatorems-784a1"

# Limite Firestore per batch write
BATCH_SIZE = 450


# ----------------------------------------------------------------------------
# Helpers di mapping record -> documento Firestore
# ----------------------------------------------------------------------------

def asl_to_doc(asl: AslRecord) -> dict[str, Any]:
    return {"codice": asl.codice, "descrizione": asl.descrizione}


def distretto_to_doc(d: DistrettoRecord) -> dict[str, Any]:
    return {
        "codice": d.codice,
        "nrDistretto": d.nr_distretto,
        "descrizione": d.descrizione,
        "codiceAsl": d.codice_asl,
    }


def zona_to_doc(z: ZonaRecord) -> dict[str, Any]:
    return {"nome": z.nome, "coloreHex": z.colore_hex}


def medico_to_doc(m: MedicoRecord) -> dict[str, Any]:
    return {
        "nome": m.nome,
        "telefono": m.telefono,
        "specializzazioneId": m.specializzazione_id,
        "prodotti": m.prodotti,
        "annotazioni": m.annotazioni,
        "periodicitaGiorni": m.periodicita_giorni,
    }


def fascia_to_doc(f: FasciaRecord, id_medico: str, zona_id_resolved: str) -> dict[str, Any]:
    return {
        "idMedico": id_medico,
        "nr": f.nr,
        "minutiInizio": f.minuti_inizio,
        "minutiFine": f.minuti_fine,
        "slotDisponibili": 1,
        "giorniSettimana": f.giorni_settimana,
        "distrettoId": f.distretto_id,
        "zonaId": zona_id_resolved,
        "struttura": f.struttura,
        "indirizzo": f.indirizzo,
        "tempoVisitaMinuti": None,
        "deleted": False,
        "isFittizia": getattr(f, "is_fittizia", False),
        "idArea": f.id_area,
    }


# ----------------------------------------------------------------------------
# Client Firestore
# ----------------------------------------------------------------------------

class FirebaseClient:
    """Wrapper leggero attorno a firebase_admin.firestore.

    Inizializzazione lazy: la connessione avviene al primo accesso.
    """

    def __init__(self, service_account_path: Optional[str] = None) -> None:
        self._service_account_path = service_account_path or os.environ.get(
            SERVICE_ACCOUNT_ENV, DEFAULT_SERVICE_ACCOUNT_PATH
        )
        self._db = None

    @property
    def db(self):
        if self._db is None:
            self._init()
        return self._db

    def _init(self) -> None:
        try:
            import firebase_admin
            from firebase_admin import credentials, firestore
        except ImportError as e:
            raise RuntimeError(
                "firebase-admin non installato. Esegui: pip install -r scripts/requirements.txt"
            ) from e

        if not os.path.exists(self._service_account_path):
            raise FileNotFoundError(
                f"Service account key non trovato: {self._service_account_path}\n"
                f"Scaricalo dalla Firebase Console: "
                f"Project settings > Service accounts > Generate new private key\n"
                f"e salvalo in scripts/serviceAccountKey.json"
            )

        # Verifica che l'app non sia gia' inizializzata
        if not firebase_admin._apps:
            cred = credentials.Certificate(self._service_account_path)
            firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})

        self._db = firestore.client()

    # ------------------------------------------------------------------
    # Lettura
    # ------------------------------------------------------------------

    def get_all(self, collection: str) -> list[dict[str, Any]]:
        """Legge tutti i documenti di una collection."""
        docs = self.db.collection(collection).stream()
        return [{**doc.to_dict(), "_docId": doc.id} for doc in docs]

    def get_specializzazioni_lookup(self) -> dict[str, str]:
        """Restituisce dict {nome_lower: docId} per le specializzazioni."""
        result: dict[str, str] = {}
        for doc in self.db.collection("specializzazioni").stream():
            data = doc.to_dict()
            nome = (data.get("nome") or "").strip().lower()
            if nome:
                result[nome] = doc.id
        return result

    # ------------------------------------------------------------------
    # Wipe
    # ------------------------------------------------------------------

    def wipe_collections(self, collections: Iterable[str]) -> dict[str, int]:
        """Cancella TUTTI i documenti delle collection indicate.

        Returns:
            dict {collection: numero_documenti_cancellati}.
        """
        counts: dict[str, int] = {}
        for coll in collections:
            count = 0
            # Cancella a batch per evitare limiti di memoria
            docs = self.db.collection(coll).limit(BATCH_SIZE).stream()
            docs_list = list(docs)
            while docs_list:
                batch = self.db.batch()
                for d in docs_list:
                    batch.delete(d.reference)
                batch.commit()
                count += len(docs_list)
                docs_list = list(
                    self.db.collection(coll).limit(BATCH_SIZE).stream()
                )
            counts[coll] = count
        return counts

    # ------------------------------------------------------------------
    # Insert
    # ------------------------------------------------------------------

    def insert_asl(self, asl_list: list[AslRecord]) -> None:
        """Inserisce le ASL con docId = codice (as stringa)."""
        for asl in asl_list:
            self.db.collection("asl").document(str(asl.codice)).set(asl_to_doc(asl))

    def insert_distretti(self, distretti: list[DistrettoRecord]) -> None:
        """Inserisce i distretti con docId = codice."""
        for d in distretti:
            self.db.collection("distretti").document(str(d.codice)).set(distretto_to_doc(d))

    def insert_zone(self, zone: list[ZonaRecord]) -> list[str]:
        """Inserisce le zone (docId auto-generato) e ritorna la lista di id
        nello stesso ordine di `zone`."""
        ids: list[str] = []
        for z in zone:
            ref = self.db.collection("zone").document()
            ref.set(zona_to_doc(z))
            ids.append(ref.id)
        return ids

    def insert_medici_batch(
        self, medici: list[MedicoRecord]
    ) -> list[str]:
        """Inserisce i medici a batch e ritorna gli id nello stesso ordine.

        NB: usiamo un campo _seq_index temporaneo nel documento per poter
        recuperare l'id dopo il commit (alternativa piu' pulita: usare
        un transaction, ma batch e' sufficiente per il nostro caso).
        """
        # Strategia: per ogni medico creiamo un doc con un campo marker
        # _marker = True, poi dopo il commit leggiamo i marker e li cancelliamo.
        # Piu' semplice: usiamo db.collection().document() che ritorna un ref
        # senza commit, e salviamo l'id PRIMA del commit.
        ids: list[str] = []
        batch = self.db.batch()
        counter = 0
        for m in medici:
            ref = self.db.collection("medici").document()
            batch.set(ref, medico_to_doc(m))
            ids.append(ref.id)
            counter += 1
            if counter >= BATCH_SIZE:
                batch.commit()
                batch = self.db.batch()
                counter = 0
        if counter > 0:
            batch.commit()
        return ids

    def insert_fasce_batch(
        self,
        fasce_per_medico: list[list[FasciaRecord]],
        medico_ids: list[str],
        zona_id_by_index: list[str],
    ) -> int:
        """Inserisce tutte le fasce orarie. Risolve zonaId tramite indice.

        Returns:
            Numero totale di fasce inserite.
        """
        total = 0
        batch = self.db.batch()
        counter = 0
        for medico_id, fasce in zip(medico_ids, fasce_per_medico):
            for fascia in fasce:
                zona_resolved = (
                    zona_id_by_index[fascia.zona_id]
                    if fascia.zona_id is not None and 0 <= fascia.zona_id < len(zona_id_by_index)
                    else None
                )
                ref = self.db.collection("fasceOrarie").document()
                batch.set(ref, fascia_to_doc(fascia, medico_id, zona_resolved or ""))
                counter += 1
                total += 1
                if counter >= BATCH_SIZE:
                    batch.commit()
                    batch = self.db.batch()
                    counter = 0
        if counter > 0:
            batch.commit()
        return total


# ----------------------------------------------------------------------------
# Test isolato (richiede serviceAccountKey.json)
# ----------------------------------------------------------------------------

if __name__ == "__main__":
    print("Questo modulo non ha un test eseguibile senza serviceAccountKey.json.")
    print("Genera il service account dalla Firebase Console e salvalo in:")
    print(f"  scripts/{DEFAULT_SERVICE_ACCOUNT_PATH}")
