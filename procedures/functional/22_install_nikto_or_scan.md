# F22 - install_nikto_or_scan.yml

Uruchom playbook z maszyny `management`. Playbook instaluje Nikto na `scanner_servers` i uruchamia skan przeciw hostom z `nikto_target_group` (domyslnie `blue_group`), pobierajac raporty na mastera do `reports/nikto/<batch_id>/`.

## 1) Test zainstalowanej wersji pakietu

```bash
ansible scanner_servers -b -m command -a 'dpkg-query -W -f=${Version} nikto'
```

Wyjasnienie: sprawdza, czy zainstalowana wersja Nikto odpowiada wersji z baseline (`package_versions_scanner.nikto`).

## 2) Test blokady hold pakietu

```bash
ansible scanner_servers -b -m command -a "apt-mark showhold" | grep nikto
```

Wyjasnienie: playbook zawsze na koncu (`always`) ustawia `hold` na pakiecie `nikto`, niezaleznie od tego, czy skan sie powiodl. `nikto` musi byc na liscie.

## 3) Test pobranych raportow na masterze

```bash
ls -la ./playbooks/reports/nikto/
```

Wyjasnienie: po kazdym uruchomieniu playbook tworzy katalog `reports/nikto/<batch_id>/` (na podstawie znacznika czasu) i pobiera do niego pliki `.txt` z wynikami skanu dla kazdego celu. Sprawdz najnowszy katalog i upewnij sie, ze zawiera pliki dla wszystkich hostow z `nikto_target_group`.

## 4) Test tresci raportu skanu

```bash
cat ./playbooks/reports/nikto/<batch_id>/nikto_<batch_id>_scanner_<host>_<port>.txt
```

Wyjasnienie: raport Nikto powinien zawierac naglowek `- Nikto v...`, docelowy adres/port oraz sekcje znalezisk (nawet jesli pusta, powinna konczyc sie podsumowaniem `+ <n> host(s) tested`). Brak pliku lub pusta tresc oznacza, ze skan nie zakonczyl sie poprawnie.

## Test funkcjonalnosci

**PASS**: Nikto jest zainstalowany w wersji z baseline, zablokowany `hold`, skan wykonal sie dla wszystkich celow z `nikto_target_group`, a raporty trafily do `reports/nikto/<batch_id>/` na masterze.


**Uwaga**: `failed_when: false` przy zadaniach skanowania i pobierania raportow oznacza, ze nawet gdy Nikto zwroci blad HTTP lub cel bedzie niedostepny, playbook nie przerwie sie - sprawdz tresc raportu, a nie tylko status zadania Ansible.
