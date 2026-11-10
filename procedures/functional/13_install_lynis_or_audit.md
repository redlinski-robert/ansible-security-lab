# F13 - install_lynis_or_audit.yml

Uruchom playbook (jesli jest aktywny dla konkretnej grupy). Z maszyny `management` sprawdz:



Wykonaj `lynis audit system` i sprawdz wygenerowany raport w `/var/log/lynis-report.dat` lub domyslnej lokalizacji.
## 1) Test zainstalowanych pakietow i wersji

```bash
ansible blue_group -b -m shell -a "dpkg-query -W lynis || lynis --version"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

## Test funkcjonalnosci

**PASS**: narzedzie jest zainstalowane, audyt sie wykonal bez bledow krytycznych, a raport zawiera wyniki skanowania. Logi powinny byc dostepne w `reports/lynis/`.


