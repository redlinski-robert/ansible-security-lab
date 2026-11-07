# F28 - enforce_version_baseline.yml

Przed zastosowaniem, z maszyny `management` sprawdz dostepnosc pakietu:
Po uruchomieniu playbooka porownaj wersje z `package_versions_effective`:
Sprawdz raport w `reports/version_baseline/`. Kazda pozycja ma konczyc sie `[ok]`.

## 1) Test poprawnosci dzialania i konfiguracji

```bash
ansible all -b -m command -a "apt-cache policy PACKAGE"
```

Wyjasnienie: ta komenda sprawdza bezposrednio stan po wdrozeniu i pozwala potwierdzic, ze usluga, uzytkownik lub plik dziala zgodnie z wymaganym rezultatem.

## 2) Test zainstalowanych pakietow i wersji

```bash
ansible all -b -m shell -a 'dpkg-query -W -f="\${Package} \${Version}\n" PACKAGE'
```

Wyjasnienie: Komenda `dpkg-query` zwraca zainstalowana wersje pakietu `PACKAGE`. Znak `$` musi byc poprzedzony backslashem (`\$`), aby powloka bash na wezle zdalnym nie potraktowala `${Package}` i `${Version}` jako pustych zmiennych srodowiskowych powloki.

## Test funkcjonalnosci

**PASS**: wszystkie wersje sa identyczne lub doprowadzone do zgodności z baseline. Obecna implementacja ma `failed_when: false` przy instalacji i kontroli, dlatego sukces calego playbooka bez `[ok]` lub `[changed]` dla wszystkich pozycji jest FAIL, a nie PASS.


