# F16 - install_hydra_or_attack.yml

Uruchom playbook (jesli jest aktywny dla konkretnej grupy). Z maszyny `management` sprawdz:
## 1) Test zainstalowanych pakietow i wersji

```bash
ansible scanner_servers -b -m shell -a "dpkg-query -W hydra || hydra --version"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

## Test funkcjonalnosci

**PASS**: narzedzie jest zainstalowane i dostepne do uzytku.

