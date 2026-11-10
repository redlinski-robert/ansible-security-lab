# F26 - enforce_file_baseline.yml

Wybierz jedna niekrytyczna pozycje z `permission_baseline` i zapisz jej stan. Celowo zmien tryb, wlasciciela lub - dla pliku posiadajacego zrodlo w `playbooks/files` - zawartosc. 

Najpierw uruchom playbook z `--check --diff`: nie moze naprawic hosta, ale powinien wykazac rozbieznosc w raporcie. Nastepnie uruchom normalnie. Z maszyny `management` sprawdz wybrany plik baseline:



Porownaj sume kontrolna z odpowiednim plikiem w `playbooks/files/` (jesli plik ma wzorzec) oraz sprawdz raport `reports/file_baseline/HOST-file-baseline-report.txt` na masterze.

## 1) Weryfikacja stanu pliku (uprawnienia, wlasciciel, suma kontrolna)

Plik wzorcowy na masterze (opcjonalnie, jesli istnieje):
```bash
sha256sum playbooks/files/NAZWA_PLIKU
```

Pliki na wezlach zdalnych:
```bash
ansible all -b -m shell -a "stat -c '%U:%G %a %n' PATH; sha256sum PATH"
```

Wyjasnienie: Pierwsza komenda oblicza sume SHA256 pliku wzorcowego z repozytorium na masterze. Druga komenda sprawdza wlasciciela (`%U`), grupe (`%G`), uprawnienia (`%a`) i sume SHA256 dla pliku `PATH` na wezlach zdalnych. Obie sumy kontrolne powinny byc zgodne.

**Uwaga (controller_baseline):**  

Pliki nalezace do `controller_baseline` (np. `inventories/hosts.yml`) znajduja sie wylacznie na masterze (`localhost`). Aby je zweryfikowac, zamiast `ansible all` uzyj `ansible localhost` lub sprawdz je lokalnie:
>```bash
>ansible localhost -m shell -a "stat -c '%U:%G %a %n' PATH; sha256sum PATH"
>```

## Test funkcjonalnosci

**PASS**: stan zostal naprawiony, hashe sa zgodne, raport koncowy nie zawiera niezgodnosci, a drugi przebieg ma `changed=0`. Po tescie przywroc migawke, jesli obiekt byl systemowy.


