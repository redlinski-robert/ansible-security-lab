# F27 - enforce_sudo_baseline.yml

Utworz kontrolowany, niezgodny plik `*-user` lub dodatkowe czlonkostwo testowego uzytkownika w znanej grupie uprzywilejowanej. Po uruchomieniu playbooka, z maszyny `management` wykonaj:



Zastap `USER` kontem uzytym w tescie. Negatywny test konta bez sudo wykonaj w oddzielnej sesji SSH.
## 1) Test skladni sudoers

```bash
ansible all -b -m command -a "visudo -cf /etc/sudoers"
```

Wyjasnienie: `visudo -cf` sprawdza poprawnosc skladni pliku sudoers. To jest kontrola bezpieczenstwa, bo nawet mala pomylka w konfiguracji moze zablokowac sudo albo wprowadzic niebezpieczne uprawnienia.

## 2) Test plikow w katalogu sudoers.d

```bash
ansible all -b -m shell -a "find /etc/sudoers.d -maxdepth 1 -type f -printf '%m %u:%g %p\n'"
```

Wyjasnienie: ta komenda pokazuje liste plikow zasady sudo i ich prawa dostepu. Pozwala sprawdzic, czy nie ma niezgodnych wpisow oraz czy pliki maja oczekiwane uprawnienia `root:root` i `0440`.

## 3) Test identyfikacji uzytkownika docelowego

```bash
ansible all -b -m command -a "id USER"
```

Wyjasnienie: `id USER` potwierdza, czy uzytkownik istnieje i do jakich grup nalezy. To kluczowa kontrola, bo skutecznosc polityki sudo zalezy zarowno od uzytkownika, jak i od jego czlonkostwa w odpowiednich grupach.

## 4) Test efektownych uprawnien sudo uzytkownika

```bash
ansible all -b -m command -a "sudo -l -U USER"
```

Wyjasnienie: ta komenda pokazuje, jakie polecenia uzytkownik moze wykonywac przez sudo. To jest ostateczna weryfikacja, czy polityka sudo odpowiada wymaganej bazie i czy nie zostala naruszona przez nieautoryzowane wpisy.

## Test funkcjonalnosci

**PASS**: dozwolone pliki maja `root:root 0440`, niezgodne zarzadzane pliki i czlonkostwa zniknely, a efektywne sudo odpowiada dokladnie `baseline_sudo_accounts_check`. Test negatywny: uzytkownik bez uprawnienia nie moze wykonac `sudo -n true`. Drugi przebieg ma `changed=0` poza kontrola etckeeper.


