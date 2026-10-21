FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY core/requirements.txt ./core/
RUN pip install --no-cache-dir -r core/requirements.txt

COPY core/ ./core/

EXPOSE 4000

ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8

CMD ["litellm", "--config", "core/config.yaml", "--host", "0.0.0.0", "--port", "4000"]
