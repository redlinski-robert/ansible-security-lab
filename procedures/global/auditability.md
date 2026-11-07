# Procedura testowa audytowalnosci etckeeper

## Cel testu
Sprawdzenie, czy zmiany w `/etc` wykonane podczas sekwencji playbookow sa
widoczne w historii etckeeper, oraz zebranie informacji o commitach i
niezatwierdzonych zmianach na kazdym hoscie.

## Zakres
- Hosty: `all` z `inventories/hosts.yml`
- Skrypt testowy: `test_etckeeper_auditability.sh`
- Repozytorium etckeeper: `/etc` na kazdym hoscie docelowym

> Wszystkie komendy wykonuj na maszynie `management`, z katalogu glownego
> projektu `ansible-lab`, tylko w przygotowanym srodowisku laboratoryjnym.
> Skrypt rzeczywiscie zmienia stan maszyn: m.in. tworzy konto awaryjne,
> zmienia uzytkownikow i hasla, instaluje pakiety, zmienia konfiguracje oraz
> restartuje systemy. Przed uruchomieniem uzupelnij znaczniki w konfiguracji
> i skrypcie, sprawdz polaczenie i dostep sudo oraz przygotuj mozliwosc
> przywrocenia srodowiska. W trakcie testu moze byc wymagane haslo sudo.

## Procedura testowa

### 1. Sprawdz inventory
```bash
ansible-inventory -i inventories/hosts.yml --graph
```

Potwierdz, ze inventory zawiera oczekiwane hosty. Kazdy host ma osobne
repozytorium `/etc`, wiec jego historia i identyfikatory commitow moga sie roznic.

### 2. Uruchom test
```bash
bash test_etckeeper_auditability.sh
```

Skrypt sprawdza i wlacza synchronizacje czasu, tworzy grupe `my-test-group`
i konto `my-test-user` oraz konfiguruje dla niego sudo. Nastepnie tymczasowo
zatrzymuje obecne jednostki aktualizacji, uruchamia instalacje etckeeper,
wylaczenie automatycznych aktualizacji i pozostale playbooki w kolejnosci
zapisanej w skrypcie. Trwale wylaczenie aktualizacji wykonuje odpowiedni
playbook. Zapis zmian w `/etc` nalezy do playbookow. Raport nie tworzy commitow.

Po pomyslnym przebiegu skrypt zapisuje raport w
`reports/etckeeper_auditability/DATA_CZAS/`. Jesli skrypt przerwie sie
wczesniej, raport koncowy moze nie powstac. Sprawdz blad i stan hostow.
Konto awaryjne i inne zmiany nie sa automatycznie cofane.

### 3. Sprawdz historie i statystyki zmian
```bash
ansible all -i inventories/hosts.yml -b -m command -a "git -C /etc log --all --stat --oneline"
ansible all -i inventories/hosts.yml -b -m command -a "git -C /etc log --all --oneline"
```

Wyjasnienie: sa to komendy uzywane przez skrypt do zapisania odpowiednio
`commits_full.log` i `commits_list.log`. Sprawdz, czy na odpowiednich hostach
w historii widac oczekiwane zmiany w `/etc` oraz jakie pliki obejmuja.
Brak commita dla playbooka, ktory nie zmienil `/etc`, sam w sobie nie jest
bledem.

### 4. Sprawdz klasyfikacje commitow
```bash
ansible all -i inventories/hosts.yml -b -m shell -a "git -C /etc log --all --pretty=format:'%H|%s' | while IFS='|' read -r commit message; do
    if git -C /etc diff-tree --quiet --no-commit-id --root -r \"\$commit\"; then
        echo \"[PUSTY]      \$commit \$message\"
    else
        echo \"[ZAPELNIONY] \$commit \$message\"
    fi
done"
```

Wyjasnienie: skrypt zapisuje takie podsumowanie w `commits_summary.log` i
wyswietla je w terminalu. `[PUSTY]` oznacza brak zmian wykrytych przez
`diff-tree`, a `[ZAPELNIONY]` - wykryte zmiany. Sprawdz wynik w kontekscie
historii danego hosta. Klasyfikacja sama nie potwierdza, ze wszystkie
oczekiwane zmiany zostaly zapisane.

### 5. Sprawdz niezapisane zmiany
```bash
ansible all -i inventories/hosts.yml -b -m command -a "git -C /etc status --porcelain"
```

Wyjasnienie: wynik tej kontroli skrypt zapisuje w `working_tree_status.log`.
Bezposrednio po poprawnym zakonczeniu sekwencji nie powinno byc
niezatwierdzonych zmian w `/etc`. Pozniejsze lub niezalezne zmiany moga
spowodowac niepusty wynik i wymagaja wyjasnienia. Naglowki i statusy Ansible
nie sa wpisami `git status`.

### 6. Sprawdz wybrany commit
```bash
ansible scanner -i inventories/hosts.yml -b -m command -a "git -C /etc show --stat --oneline HEAD"
ansible scanner -i inventories/hosts.yml -b -m command -a "git -C /etc show --stat --oneline __UZUPELNIJ_HASH_COMMITA__"
```

Wyjasnienie: pierwsza komenda pokazuje ostatni commit hosta `scanner`.
W drugiej podstaw hash z jego historii. Dla innego hosta uzyj jego nazwy i
hasza z jego repozytorium. Nie zakladaj, ze ten sam hash istnieje na wszystkich
hostach. Te komendy sa dodatkowymi kontrolami recznymi opisanymi w skrypcie.

## Kryteria zaliczenia
- sekwencja skryptu zakonczyla sie bez bledow, a raport zawiera wyniki dla
  wszystkich oczekiwanych hostow;
- historie i statystyki potwierdzaja oczekiwane zmiany `/etc` na odpowiednich
  hostach;
- wynik klasyfikacji commitow zostal przeanalizowany;
- bezposrednio po sekwencji nie ma niewyjasnionych, niezatwierdzonych zmian
  w `/etc`.

Skrypt zbiera dane, ale nie wystawia automatycznie wyniku `PASS` lub `FAIL`.
Brak raportu, blad komendy, brak oczekiwanego zapisu lub niewyjasnione zmiany
wymagaja wyjasnienia przed zaliczeniem.
