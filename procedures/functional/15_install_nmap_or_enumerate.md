# F15 - install_nmap_or_enumerate.yml

Uruchom playbook (jesli jest aktywny dla konkretnej grupy). Z maszyny `management` sprawdz:



Test funkcjonalny uruchom z mastera na scannerze:
## 1) Test zainstalowanych pakietow i wersji

```bash
ansible scanner_servers -b -m shell -a "dpkg-query -W nmap || nmap --version"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

## 2) Test poprawnosci dzialania i konfiguracji

```bash
ansible scanner_servers -b -m command -a "nmap -p 22,80,443 localhost"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

## Test funkcjonalnosci

**PASS**: narzedzie jest zainstalowane, scan sie wykonal bez bledow krytycznych, a wyniki sa dostepne. Raporty ze skanowania powinny byc dostepne w `reports/nmap/`.



