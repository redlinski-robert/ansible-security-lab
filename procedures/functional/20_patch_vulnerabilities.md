# F20 - patch_vulnerabilities.yml

Z maszyny `management` zapisz stan przed uruchomieniem playbooka:
Po uruchomieniu wykonaj ponownie powyzsza komende oraz sprawdz:
Liczba dostepnych aktualizacji powinna zmalec lub zostac rowna 0.

## 1) Test poprawnosci dzialania i konfiguracji

```bash
ansible blue_group -b -m shell -a "apt list --upgradable 2>/dev/null | grep -E 'vim|policykit-1' || true"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

**Oczekiwany wynik**: pusty output (brak linii) dla obu hostow - oznacza to, ze `vim`, `vim-common`, `vim-runtime` i `policykit-1` sa juz zaktualizowane do wersji z baseline i nie ma dla nich dostepnych aktualizacji.

## 2) Test zainstalowanych pakietow i wersji

```bash
ansible blue_group -b -m shell -a "dpkg -l | grep -E 'vim|policykit-1'"
```

Wyjasnienie: `dpkg -l` wyswietla zainstalowane pakiety, a `grep` ogranicza wynik do pakietow latanych przez ten playbook. Pozwala sprawdzic, jakie wersje sa obecnie zainstalowane.

**Oczekiwany wynik**: flaga `ii` przy `vim`, `vim-common`, `vim-runtime` i `policykit-1`, a wersje zgodne z `package_versions_blue` (baseline w [inventories/group_vars/blue_group/30_versions.yml](../inventories/group_vars/blue_group/30_versions.yml)).

## 3) Test pakietow zablokowanych przed aktualizacja

```bash
ansible blue_group -b -m command -a "apt-mark showhold"
```

Wyjasnienie: `apt-mark showhold` pokazuje pakiety oznaczone jako zablokowane. Wynik nalezy porownac ze stanem zapisanym przed aktualizacja, aby potwierdzic, ze playbook nie zmienil niezamierzenie pakietow `hold`.

## Test funkcjonalnosci

**PASS**: pakiety o znanych lukach bezpieczenstwa zostaly zaktualizowane, pakiety pinned (hold) pozostaly bez zmian, zaden krytyczny system nie ulegl uszkodzeniu. Jesli playbook wymaga restartu, nalezy to potwierdzic w logu.


