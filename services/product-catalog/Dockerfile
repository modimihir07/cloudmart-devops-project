FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim AS production
RUN groupadd -r cloudmart && useradd -r -g cloudmart -u 1001 -m cloudmart
WORKDIR /app
COPY --from=builder /root/.local /home/cloudmart/.local
ENV PATH=/home/cloudmart/.local/bin:$PATH
COPY app/ app/
RUN chown -R cloudmart:cloudmart /app && \
    chmod -R 755 /app && \
    find /app -type f -name "*.py" -exec chmod 444 {} \;
USER 1001
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
STOPSIGNAL SIGTERM
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
