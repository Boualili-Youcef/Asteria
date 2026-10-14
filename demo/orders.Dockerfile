# Demo-only runtime; the historical Debian Dockerfile remains unchanged.
FROM python:3.14.6-alpine3.24@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN addgroup -g 10001 asteria \
    && adduser -D -H -u 10001 -G asteria -s /sbin/nologin asteria

WORKDIR /app
COPY requirements.txt .
RUN python -m pip install --requirement requirements.txt
COPY app ./app

USER 10001:10001
EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8080", "--no-access-log"]
