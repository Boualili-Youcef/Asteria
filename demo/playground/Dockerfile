FROM python:3.14.6-alpine3.24@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && addgroup -g 10001 lab && adduser -D -H -u 10001 -G lab lab
COPY server.py ./server.py
COPY web ./web
USER 10001:10001
EXPOSE 8080
CMD ["uvicorn", "server:app", "--host=0.0.0.0", "--port=8080", "--no-access-log"]
