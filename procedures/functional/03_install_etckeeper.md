# F03 - install_etckeeper.yml

Uruchom playbook. Z maszyny `management` wykonaj:



`etckeeper status` nie jest uzywany, poniewaz w zainstalowanej wersji oczekuje katalogu `/etc/etckeeper/status.d`, ktorego ta konfiguracja nie tworzy. Poprawnym testem jest istnienie repozytorium Git oraz commita zwroconego przez `etckeeper vcs rev-parse HEAD`.

Polecenie `git -C /etc status --porcelain` powinno nie zwrocic zadnych linii bezposrednio po poprawnym zakonczeniu playbooka. Pozniejsze zmiany w `/etc` naturalnie moga sprawic, ze drzewo bedzie nieczyste.
## 1) Test zainstalowania pakietu etckeeper

```bash
ansible all -b -m command -a "dpkg-query -W etckeeper"
```

Wyjasnienie: ta komenda sprawdza, czy pakiet `etckeeper` jest zainstalowany w systemie. To jest podstawa, bez ktorej nie ma mozliwosci zarzadzania historia zmian w katalogu `/etc`.

## 2) Test obecnosci repozytorium Git dla /etc

```bash
ansible all -b -m command -a "etckeeper vcs rev-parse HEAD"
```

Wyjasnienie: `etckeeper vcs rev-parse HEAD` mowi, czy repozytorium Git w `/etc` istnieje i czy ma co najmniej jeden commit. To potwierdza, ze etckeeper zostal poprawnie zainicjalizowany i pracuje na zywym repozytorium.

## 3) Test ostatnich commitow w repozytorium /etc

```bash
ansible all -b -m command -a "git -C /etc log --oneline -n 3"
```

Wyjasnienie: ta komenda pokazuje najnowsze zmiany zapisane w historii `/etc`. To pozwala sprawdzic, ze repozytorium nie jest puste i ze zmiany konfiguracyjne sa rejestrowane zgodnie z oczekiwaniem.

## 4) Test katalogu Git /etc

```bash
ansible all -b -m command -a "ls -la /etc/.git/"
```

Wyjasnienie: ta komenda sprawdza strukture repozytorium Git i potwierdza, ze zostal utworzony wlasciwy katalog `.git` w `/etc`. To jest kontrola poprawnosci inicjalizacji etckeeper.

## 5) Test czystosci repozytorium /etc

```bash
ansible all -b -m command -a "git -C /etc status --porcelain"
```

Wyjasnienie: ta komenda pokazuje, czy w `/etc` nie ma niezsynchronizowanych zmian. Po poprawnym wdrozeniu repozytorium powinno byc czyste, a pozniejsze modyfikacje od razu beda widoczne w statusie.

## Test funkcjonalnosci

**PASS**: pakiet jest zainstalowany, repozytorium Git zostal zainicjalizowany w `/etc`, co najmniej jeden commit istnieje, a struktura katalogow jest oczekiwana. Drugi przebieg nie powinien odtwarzac repozytorium.


