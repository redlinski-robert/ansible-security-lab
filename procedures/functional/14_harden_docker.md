# F14 - harden_docker.yml

Po uruchomieniu playbooka, z maszyny `management` wykonaj:



Oczekuj m.in. `live-restore=true`, `no-new-privileges=true`, `icc=false`, `userland-proxy=false`, drivera `local` i aktywnego AuthZ, jesli wlaczony.

Uwaga: `userns-remap` jest celowo pominiety w konfiguracji - Docker nie wspiera jednoczesnego uzycia user namespace remappingu i systemu pluginow (AuthZ), wiec wybrano AuthZ.
## 1) Test poprawnosci pliku daemon.json

```bash
ansible app_servers -b -m command -a "python3 -m json.tool /etc/docker/daemon.json"
```

Wyjasnienie: ta komenda sprawdza, czy plik konfiguracji Dockera jest poprawnym JSON-em. To jest pierwszy test, ktory potwierdza, ze konfiguracja nie ma bledow skladniowych zanim Docker zostanie uruchomiony z nowymi ustawieniami. Nie wymaga `jq` (ktory nie jest domyslnie instalowany) - `python3` jest dostepny na standardowym Ubuntu. Jesli `jq` jest zainstalowany, rownie dobrze zadziala: `ansible app_servers -b -m command -a "jq empty /etc/docker/daemon.json"`.

## 2) Test informacji o daemonie Docker

```bash
ansible app_servers -b -m command -a "docker info"
```

Wyjasnienie: `docker info` pokazuje stan daemon, driver, storage, live-restore i inne wlasciwosci runtime. To jest najbezposredniejsza kontrola, czy Docker dziala z poprawnym ustawieniem bezpieczenstwa i storage.

## 3) Test aktywnosci daemon Docker

```bash
ansible app_servers -b -m shell -a "systemctl is-active docker"
```

Wyjasnienie: ta komenda sprawdza, czy daemon Docker jest rzeczywiscie aktywny. Jesli usluga nie dziala, wszystkie dalsze testy bezpieczenstwa i wydajnosci sa niewiarygodne.

## 4) Test aktywnosci uslugi auditd

```bash
ansible app_servers -b -m shell -a "systemctl is-active auditd"
```

Wyjasnienie: `auditd` odpowiada za rejestrowanie zdarzen bezpieczenstwa. Ta kontrola potwierdza, ze monitorowanie Docker i jego zdarzen jest aktywne i nie zostal wylaczony przez konfiguracje.

## 5) Test regul auditd

```bash
ansible app_servers -b -m command -a "auditctl -l"
```

Wyjasnienie: ta komenda pokazuje aktywne reguly auditd. Pozwala sprawdzic, czy konfiguracja monitorowania bezpieczenstwa zostala zaladowana i czy zdarzenia sa faktycznie rejestrowane.

## 6) Test zainstalowanych pluginow Docker

```bash
ansible app_servers -b -m command -a "docker plugin ls"
```

Wyjasnienie: to sprawdza, czy zainstalowane sa tylko oczekiwane pluginy i czy nie ma dodatkowych, nieautoryzowanych modulow. To wazna kontrola bezpieczenstwa srodowiska Docker.

## Testy egzekwowania polityki AuthZ (proby naruszenia)

Ponizsze komendy powinny zostac **odrzucone** przez `opa-docker-authz` (blad typu `authorization denied by plugin opa-docker-authz`). Jesli ktorakolwiek sie powiedzie, polityka w `docker-authz.rego` nie dziala poprawnie.

### 7) Kontener uprzywilejowany (Privileged)

```bash
ansible app_servers -b -m shell -a "docker run --rm --privileged alpine echo test"
```

### 8) Tryb sieci hosta (NetworkMode=host)

```bash
ansible app_servers -b -m shell -a "docker run --rm --network host alpine echo test"
```

### 9) Tryb PID hosta (PidMode=host)

```bash
ansible app_servers -b -m shell -a "docker run --rm --pid host alpine echo test"
```

### 10) Tryb IPC hosta (IpcMode=host)

```bash
ansible app_servers -b -m shell -a "docker run --rm --ipc host alpine echo test"
```

### 11) Tryb user namespace hosta (UsernsMode=host)

```bash
ansible app_servers -b -m shell -a "docker run --rm --userns host alpine echo test"
```

### 12) Dodanie capability SYS_ADMIN

```bash
ansible app_servers -b -m shell -a "docker run --rm --cap-add=SYS_ADMIN alpine echo test"
```

### 13) Przekazanie urzadzenia hosta do kontenera

```bash
ansible app_servers -b -m shell -a "docker run --rm --device=/dev/sda alpine echo test"
```

### 14) Wylaczenie profilu seccomp

```bash
ansible app_servers -b -m shell -a "docker run --rm --security-opt seccomp=unconfined alpine echo test"
```

### 15) Wylaczenie profilu AppArmor

```bash
ansible app_servers -b -m shell -a "docker run --rm --security-opt apparmor=unconfined alpine echo test"
```

### 16) Montowanie docker.sock do kontenera

```bash
ansible app_servers -b -m shell -a "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock alpine echo test"
```

### 17) Montowanie calego systemu plikow hosta ("/")

```bash
ansible app_servers -b -m shell -a "docker run --rm -v /:/hostroot alpine echo test"
```

### 18) Modyfikacja pluginow Docker (np. instalacja nowego)

```bash
ansible app_servers -b -m shell -a "docker plugin disable opa-docker-authz"
```

Wyjasnienie (7-18): kazda z powyzszych komend celowo lamie jedna regule `deny` z `docker-authz.rego`. Oczekiwany wynik to blad Docker API z odmowa autoryzacji (rc != 0, komunikat wspominajacy `opa-docker-authz` lub "not authorized"/"denied"). Sukces ktorejkolwiek komendy oznacza FAIL - polityka nie jest egzekwowana.

### 19) Test pozytywny - zgodny z polityka kontener powinien wystartowac

```bash
ansible app_servers -b -m shell -a "docker run --rm alpine echo ok"
```

Wyjasnienie: potwierdza brak false-positive - normalna, zgodna z polityka operacja nie zostaje zablokowana przez AuthZ.

## Testy funkcjonalne hardeningu daemon.json

### 20) Test icc=false - izolacja sieciowa miedzy kontenerami na domyslnym mostku

```bash
ansible app_servers -b -m shell -a "docker rm -f icc_a 2>/dev/null; docker run -d --name icc_a alpine sleep 60; sleep 1; ip=\$(docker inspect icc_a | python3 -c 'import json,sys;d=json.load(sys.stdin)[0][\"NetworkSettings\"];print(d.get(\"IPAddress\") or list(d[\"Networks\"].values())[0][\"IPAddress\"])'); docker run --rm alpine ping -c1 -W2 \$ip; docker rm -f icc_a"
```

Wyjasnienie: `icc` w `daemon.json` dotyczy wylacznie domyslnego mostka `bridge` (`docker0`) - sieci zdefiniowane przez uzytkownika (`docker network create`) zawsze maja wlaczona komunikacje miedzy kontenerami niezaleznie od tego ustawienia, wiec test musi uzywac domyslnej sieci. Przy `icc=false` `ping` po adresie IP kontenera `icc_a` powinien zakonczyc sie niepowodzeniem/timeoutem (100% packet loss).

Uwaga: `\$(...)` i `\$ip` musza byc poprzedzone `\`, bo inaczej lokalny shell na `management` rozwinie je PRZED wyslaniem komendy przez Ansible (a `docker` nie jest zainstalowany na `management`), przez co `ip` wyjdzie puste. Do odczytania adresu IP uzyto `python3` zamiast `docker inspect -f '{{.NetworkSettings.IPAddress}}'`, bo Ansible sam templatuje wartosc `-a` silnikiem Jinja2 i myli skladnie `{{ }}` z Go template Dockera z wlasnym szablonem, co konczy sie bledem `template error while templating string`. Skrypt python najpierw probuje `NetworkSettings.IPAddress` (bywa puste na niektorych wersjach API), a w razie braku siega do `NetworkSettings.Networks.bridge.IPAddress`.

### 21) Test no-new-privileges - kontenery nie moga podnosic uprawnien

```bash
ansible app_servers -b -m shell -a "docker run --rm alpine cat /proc/1/status | grep NoNewPrivs"
```

Wyjasnienie: wartosc `NoNewPrivs: 1` potwierdza, ze ustawienie domyslne z `daemon.json` jest dziedziczone przez kazdy nowy kontener, nawet bez jawnego `--security-opt no-new-privileges`.

### 22) Test live-restore - kontenery przezywaja restart daemona

```bash
ansible app_servers -b -m shell -a "docker run -d --name livetest alpine sleep 300"
ansible app_servers -b -m shell -a "systemctl restart docker"
ansible app_servers -b -m shell -a "docker ps --filter name=livetest --format {% raw %}'{{.Status}}'{% endraw %}"
ansible app_servers -b -m shell -a "docker rm -f livetest"
```

Wyjasnienie: dzieki `live-restore=true` kontener `livetest` powinien pozostac uruchomiony (status `Up`, bez restartu) mimo restartu uslugi `docker.service`. `{% raw %}...{% endraw %}` jest konieczne, bo Ansible sam templatuje wartosc `-a` silnikiem Jinja2 i bez tego myli skladnie `{{.Status}}` Dockera (Go template) z wlasna - konczy sie to bledem `template error while templating string`.

### 23) Test userland-proxy=false - brak procesu docker-proxy dla opublikowanych portow

```bash
ansible app_servers -b -m shell -a "docker run -d --name proxytest -p 8080:80 alpine sleep 60"
ansible app_servers -b -m shell -a "pgrep -x docker-proxy || echo 'brak procesu docker-proxy'"
ansible app_servers -b -m shell -a "docker rm -f proxytest"
```

Wyjasnienie: przy `userland-proxy=false` przekierowanie portu obsluguje wylacznie iptables/NAT jadra, wiec `pgrep` powinien wypisac `brak procesu docker-proxy` (rc=0 z `||`), a nie zaden PID. Uzyto `pgrep -x` (dopasowanie po dokladnej nazwie procesu), a nie `pgrep -f`/`ps aux | grep` (dopasowanie po pelnej linii polecen) - `-f` lapie tez proces powloki `/bin/sh -c "pgrep -f '...'"`, ktorego linia polecen zawiera ten sam szukany tekst, wiec mimo wykluczenia wlasnego PID przez `pgrep`, nadal lapie proces-rodzica. `-x` porownuje tylko sama nazwe binarki (`docker-proxy` vs `sh`), wiec nie ma tej kolizji.

Alternatywa (klasyczny trik z klasa znakow zamiast `pgrep -x`):

```bash
ansible app_servers -b -m shell -a "ps aux | grep '[d]ocker-proxy.*8080' || echo 'brak procesu docker-proxy'"
```

Tu `[d]ocker-proxy` w tekscie wejsciowym `ps aux` nie zawiera doslownych nawiasow kwadratowych (to prawdziwa nazwa procesu), wiec dopasuje sie tylko do rzeczywistego `docker-proxy`, a nie do linii samego `grep`/`sh -c`, ktore w swoim argumencie maja doslowne `[d]` (patrz wczesniejsza dyskusja o klasach znakow).

Czym jest "klasa znakow": `[d]` w regexie to nie doslowny ciag trzech znakow `[`, `d`, `]`, tylko zapis oznaczajacy "dokladnie jeden znak ze zbioru w nawiasach" - tutaj zbior ma jeden element, wiec `[d]` w praktyce dopasowuje sie tak samo jak zwykle `d`. Dzieki temu regex `[d]ocker-proxy` dopasowuje ten sam tekst co `docker-proxy` (prawdziwy proces), ale linia procesu `grep`/powloki, ktora doslownie zawiera znaki `[`, `d`, `]` w swoim argumencie (bo to i tak trzeba bylo napisac jako string wzorca), nie zawiera nigdzie sekwencji `d` bezposrednio po niej `ocker-proxy` - miedzy `d` a `ocker` stoi tam `]`, wiec nie ma dopasowania. To pozwala odroznic prawdziwy proces od self-matchu bez zmiany sensu wzorca.

Dowod, ze linia grepa naprawde tam jest, tylko normalnie niewidoczna: uzyj `grep -F` (dopasowanie doslowne, bez interpretacji regex), zeby zobaczyc dokladnie te linie, ktora przy zwyklym `grep '[d]...'` jest odfiltrowana:

```bash
ansible app_servers -b -m shell -a "ps aux | grep -F '[d]ocker-proxy'"
```

W trybie `-F` nawiasy `[` i `]` przestaja byc metaznakami regexu i staja sie zwyklymi literami do wyszukania, wiec ta komenda pokaze wlasnie linie samego `grep`/powloki (bo ich argumenty doslownie zawieraja tekst `[d]ocker-proxy`), a NIE pokaze prawdziwego procesu `docker-proxy` (bo jego argv nie ma w sobie nawiasow kwadratowych). To jest odwrotnosc normalnego testu - potwierdza, ze mechanizm faktycznie polega na roznicy miedzy dopasowaniem regexowym a doslownym, a nie na tym, ze ta linia "nie istnieje".

Mozna ten trik przetestowac w nastepujacy sposob:
```bash
ansible app_servers -b -m shell -a "ps aux | grep 'sleep'"
ansible app_servers -b -m shell -a "ps aux | grep '[s]leep'"
```

## Test funkcjonalnosci


**PASS**: konfiguracja demona i hosta jest zgodna z wymaganiami hardeningu, a testy procesow i kontenerow potwierdzaja oczekiwane dzialanie.

