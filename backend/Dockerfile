FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --default-timeout=300 --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt
RUN pip install --default-timeout=300 --trusted-host pypi.org --trusted-host files.pythonhosted.org gunicorn

COPY server.py .
COPY enrolled_faces.json .

ENV PORT=8080
EXPOSE 8080

CMD exec gunicorn --bind :$PORT --workers 1 --threads 4 --timeout 120 server:app