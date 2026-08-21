# Image multi-étapes. L'étape `production` est la dernière : un `docker build`
# sans `--target` la sélectionne, ce qui est le comportement des hébergeurs
# manageés (Railway, Render…). Le développement demande explicitement
# `target: development` — voir `docker-compose.yml`.

# --- Socle commun -----------------------------------------------------------
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Dépendances d'abord : le cache de couche survit aux changements de code.
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# --- Développement ----------------------------------------------------------
# Ajoute pytest et httpx, absents de l'image déployée. Le code est monté en
# volume par docker-compose, qui surcharge aussi la commande.
FROM base AS development

COPY requirements-dev.txt ./
RUN pip install -r requirements-dev.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# --- Production -------------------------------------------------------------
FROM base AS production

COPY . .

# Utilisateur non privilégié. `uploads/` doit lui appartenir : l'application y
# écrit les justificatifs et crée le dossier au démarrage.
RUN useradd --create-home --uid 10001 kadjane \
    && mkdir -p /app/uploads \
    && chown -R kadjane:kadjane /app
USER kadjane

EXPOSE 8000

# Les migrations tournent au démarrage : sans elles le schéma n'existe pas et
# chaque requête répond 500. `exec` laisse uvicorn recevoir les signaux d'arrêt.
#
# `PORT` est imposé par l'hébergeur — le figer ferait échouer son healthcheck.
# `WEB_CONCURRENCY` règle le nombre de processus (1 suffit pour la Beta).
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-1}"]
