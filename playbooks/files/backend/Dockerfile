# Lekki obraz bazowy ogranicza rozmiar obrazu runtime.
FROM python:3.9-slim

# Wszystkie pliki aplikacji i polecenia uruchamiamy z tego katalogu.
WORKDIR /app

# curl jest wymagany przez testy zdrowia lub diagnostyke kontenera.
# Czyszczenie cache APT zmniejsza rozmiar finalnego obrazu.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Zaleznosci sa instalowane bez lokalnego cache pip.
RUN pip install --no-cache-dir redis flask flask-cors

# Aplikacja jest jedynym plikiem z kodem kopiowanym do obrazu.
COPY app.py .

# Dokumentacja portu uzywanego przez Flask; publikowanie portu definiuje Compose.
EXPOSE 5000

# Kontener uruchamia aplikacje bez dodatkowego procesu startowego.
CMD ["python", "app.py"]