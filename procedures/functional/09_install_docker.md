# F09 - install_docker.yml

Playbook jest przeznaczony dla grupy `app` i pobiera wersje pakietow z baseline zdefiniowanego w inventory (`package_versions_effective` oraz sekcja `app_servers/30_versions.yml`).

Uruchom playbook. Z maszyny `management` sprawdz:
## 1) Test wlaczenia uslugi Docker przy starcie

```bash
ansible app -b -m shell -a "systemctl is-enabled docker"
```

Wyjasnienie: `systemctl is-enabled` pokazuje, czy Docker ma byc automatycznie uruchamiany po starcie systemu. To jest test trwalosci instalacji, bo dzialajacy Docker tylko na jednej sesji nie jest wystarczajacy.

## 2) Test aktywnosci uslugi Docker

```bash
ansible app -b -m shell -a "systemctl is-active docker"
```

Wyjasnienie: ta komenda sprawdza, czy daemon Docker jest aktywnie uruchomiony. Bez tego klient `docker` nie bedzie mogl komunikowac sie z engine i wszystkie dalsze testy beda niepoprawne.

## 3) Test wersji CLI Docker

```bash
ansible app -b -m command -a "docker version"
```

Wyjasnienie: `docker version` pokazuje wersje klienta i daemon, a takze czy komunikacja miedzy nimi dziala. To jest szybki test, czy instalacja Docker Engine i CLI sa zgodne i poprawnie polaczone.

## 4) Test wersji Docker Compose

```bash
ansible app -b -m command -a "docker compose version"
```

Wyjasnienie: ta komenda sprawdza, czy plugin Compose jest zainstalowany i dostepny. To wazne przy wdrozeniach opartych na `docker-compose.yml`, bo brak pluginu oznacza brak mozliwosci uruchamiania kontenerow z definicji.

## 5) Test pakietow trzymanych przez APT

```bash
ansible app -b -m command -a "apt-mark showhold"
```

Wyjasnienie: `apt-mark showhold` pokazuje, ktore pakiety sa zablokowane na okreslonej wersji. To potwierdza, ze instalacja jest zgodna z baseline i nie ma przypadkowej aktualizacji do innej wersji.

## 6) Test wersji biblioteki Docker Python

```bash
ansible app -b -m command -a "python3 -c 'import docker; print(docker.__version__)'"
```

Wyjasnienie: ta komenda sprawdza, czy biblioteka Docker dla Pythona jest zainstalowana i ma oczekiwana wersje. To istotne przy automatyzacji i skryptach integrujacych sie z Docker Engine.

## 7) Test uruchomienia kontenera testowego

```bash
ansible app -b -m command -a "docker run --rm hello-world"
```

Wyjasnienie: to jest rzeczywisty test koncowy dzialania Dockera. Kontener `hello-world` musi sie uruchomic i zakonczyc poprawnie kodem 0, co dowodzi, ze daemon, runtime i srodowisko kontenera dzialaja prawidlowo.

## Test funkcjonalnosci

**PASS**: wersje sa rowne zmiennym baseline, pakiety sa hold, daemon dziala, klient komunikuje sie z daemonem i kontener testowy konczy sie kodem 0. 


