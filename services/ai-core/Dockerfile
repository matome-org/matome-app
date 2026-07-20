FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    AI_JOB_DATA_PATH=/var/lib/matome-ai-core/jobs.sqlite3

RUN apt-get update \
  && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --shell /usr/sbin/nologin app \
  && install -d -o app -g app \
       /app \
       /var/lib/matome-ai-core \
       /home/app/.cache/whisper \
       /home/app/.local/share/pywhispercpp/models

WORKDIR /app
COPY --chown=app:app pyproject.toml ./
COPY --chown=app:app app ./app
ARG WHISPER_EXTRA=whisper-openai
RUN pip install --no-cache-dir ".[${WHISPER_EXTRA}]"

USER app
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
