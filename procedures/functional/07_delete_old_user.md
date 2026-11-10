# F07 - delete_old_user.yml

Przed testem utworz wylacznie przeznaczone do usuniecia konto testowe. Po uruchomieniu playbooka, z maszyny `management` wykonaj:

W zwyklym trybie brak konta, katalogu home, procesow oraz pliku `/etc/sudoers.d/OLD-user` oznacza poprawny wynik. Proba nowego logowania jako `OLD` powinna zostac odrzucona.

`90-` to zwykla konwencja nazwy, ktora ustala kolejnosc czytania plikow w `/etc/sudoers.d`. Nie jest tworzona automatycznie przez Ansible ani system. Wspolny wpis sudoers dla grupy nie jest usuwany, poniewaz moze byc uzywany przez innych uzytkownikow. Usuniecie konta automatycznie odbiera mu czlonkostwo w grupie `sudo`.

Jesli chcesz usunac wszystkie rozpoznane prywatne wpisy sudoers, uruchom playbook z `-e force_delete_user_sudoers_files=true`. Ten rozszerzony tryb usuwa `OLD`, `OLD-user`, `NUMER-OLD` i `NUMER-OLD-user`, na przyklad `90-__UZUPELNIJ_UZYTKOWNIK_BLUE__-user`, lecz nie uzywa szerokiego dopasowania czesci nazwy uzytkownika.
## 1) Test usuniecia wpisu w passwd

```bash
ansible all -b -m shell -a "getent passwd OLD || true"
```

Wyjasnienie: ta komenda sprawdza, czy konto uzytkownika zostalo usuniete z systemu. Jesli wpis nie istnieje, to oznacza, ze uzytkownik nie jest juz aktywny i nie moze zostac uzyty do logowania.

## 2) Test usuniecia wpisu w shadow

```bash
ansible all -b -m shell -a "getent shadow OLD || true"
```

Wyjasnienie: `shadow` zawiera informacje o hasle uzytkownika. Brak wpisu potwierdza, ze konto zostalo calkowicie usuniete i nie da sie juz uzywac dawnych danych uwierzytelniajacych.

## 3) Test usuniecia katalogu domowego

```bash
ansible all -b -m shell -a "test ! -d /home/OLD && echo home-removed"
```

Wyjasnienie: ta komenda sprawdza, czy katalog domowy uzytkownika zostal usuniety oraz czy po usunieciu nie zostaja po nim zadne dane. To potwierdza, ze nie ma pozostalosci starego konta w systemie.

## 4) Test brakujacych procesow uzytkownika

```bash
ansible all -b -m shell -a "pgrep -u OLD || true"
```

Wyjasnienie: ta komenda sprawdza, czy po usunieciu uzytkownika nie zostaly uruchomione zadne jego procesy. Brak wynikow oznacza, ze konto nie dziala juz w tle i nie ma aktywnych sesji systemowych.

## 5) Test usuniecia pliku sudoers dla uzytkownika

```bash
ansible all -b -m shell -a "ls -l /etc/sudoers.d/OLD-user 2>/dev/null || true"
```

Wyjasnienie: ta komenda sprawdza, czy nie zostal pozostawiony prywatny plik sudoers dla usunietego uzytkownika. Brak takiego pliku oznacza, ze nie ma juz zapisu uprawnien sudo przypisanego do konta, ktore zostalo usuniete.

## Test funkcjonalnosci

**PASS**: konto i home nie istnieja, brak procesow, prywatne pliki sudoers zostaly usuniete, a logowanie jest niemozliwe.

