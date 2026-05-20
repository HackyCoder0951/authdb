FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libffi-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY services/tasks-services/requirements.txt ./requirements.txt
COPY shared ./shared
COPY services/tasks-services/app ./app

RUN pip install --no-cache-dir -r requirements.txt

ENV PYTHONPATH=/app
EXPOSE 8003

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8003"]
