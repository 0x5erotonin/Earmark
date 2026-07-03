# ---------- Earmark app image (Fly.io-ready) ----------
FROM python:3.12-slim

# security: run as an unprivileged user
RUN useradd --create-home appuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server/ server/
COPY static/ static/

# /data is the Fly volume mount point (fly.toml [mounts])
ENV DATA_DIR=/data \
    PORT=8080 \
    PYTHONUNBUFFERED=1
RUN mkdir -p /data && chown appuser:appuser /data /app
USER appuser

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz',timeout=2).status==200 else 1)"

CMD ["uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8080"]
