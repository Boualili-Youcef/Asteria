FROM python:3.14.6-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN groupadd --gid 10001 asteria \
    && useradd --uid 10001 --gid asteria --no-create-home --shell /usr/sbin/nologin asteria

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --requirement requirements.txt

COPY app ./app

USER 10001:10001
EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8080", "--no-access-log"]
