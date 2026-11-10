# F05 - change_user_name_or_group.yml

Stworzenie uzytkownika do testow:
ansible all -b -m group -a "name=my-test-group state=present"
ansible all -b -m user -a "name=my-test-user group=my-test-group shell=/bin/bash create_home=yes"


ansible all -b -m shell -a "printf '%s\n' 'my-test-user ALL=(ALL:ALL) ALL' > /etc/sudoers.d/my-test-user-user && chmod 0440 /etc/sudoers.d/my-test-user-user && visudo -cf /etc/sudoers"

Po uruchomieniu playbooka, z maszyny `management` sprawdz nowe dane uzytkownika:

## 1) Test wpisu uzytkownika w systemie

```bash
ansible all -b -m command -a "getent passwd USER"
```

Wyjasnienie: `getent passwd` sprawdza, czy uzytkownik jest widoczny w systemowej bazie kont i czy jego wpis zawiera oczekiwana nazwe oraz katalog domowy.

## 2) Test UID i grup uzytkownika

```bash
ansible all -b -m command -a "id USER"
```

Wyjasnienie: `id` pokazuje UID, grupe glowna i grupy dodatkowe. Pozwala potwierdzic, ze po zmianie nazwy lub grupy konto zachowalo wlasciwa tozsamosc i uprawnienia.

## 3) Test skladni sudoers

```bash
ansible all -b -m command -a "visudo -cf /etc/sudoers"
```

Wyjasnienie: `visudo -cf` sprawdza skladnie konfiguracji sudoers bez jej zmieniania. Blad oznacza, ze migracja mogla pozostawic niepoprawne reguly.

Szybkie dodanie uzytkownika do sudoers na czas testu (przed uruchomieniem playbooka):

```bash
ansible all -b -m shell -a "printf '%s\n' 'USER ALL=(ALL:ALL) ALL' > /etc/sudoers.d/USER && chmod 0440 /etc/sudoers.d/USER-user && visudo -cf /etc/sudoers"
```

Polecenie tworzy osobny plik `/etc/sudoers.d/USER`, ustawia wymagane uprawnienia `0440` i sprawdza koncowa skladnie calej konfiguracji. Zastap `USER` docelowa nazwa uzytkownika, zachowujac male litery.


## 4) Test uprawnien sudo uzytkownika

```bash
ansible all -b -m command -a "sudo -l -U USER"
```

Wyjasnienie: `sudo -l -U USER` pokazuje realne reguly sudo dla uzytkownika. Sprawdz, czy po migracji konto ma dokladnie te uprawnienia, ktore sa zgodne z polityka bezpieczenstwa.

Szybkie usuniecie uzytkownika z sudoers po tescie:

```bash
ansible all -b -m shell -a "rm -f /etc/sudoers.d/USER-user && visudo -cf /etc/sudoers"
```

Polecenie usuwa plik uprawnien uzytkownika i sprawdza koncowa skladnie sudoers. Zastap `USER` docelowa nazwa uzytkownika.

## 3) Test realnego logowania z nowa nazwa

```bash
ssh USER@HOST
```

Wyjasnienie: test logowania w nowej sesji SSH jest ostatnim i najwazniejszym sprawdzeniem uzytkownika po migracji. Jesli nowa nazwa nie loguje sie lub stara dalej dziala, zmiana nie jest poprawna z perspektywy operacyjnej.

Zastap `USER` docelowa nazwa uzytkownika. Nowe logowanie SSH wykonaj w oddzielnej sesji z mastera.

Zapisz stan `id OLD`, `getent passwd OLD`, `getent group OLD_GROUP` i sudoers. Uruchom migracje. Sprawdz `getent passwd NEW`, `id NEW`, wlasciciela `/home/NEW`, brak `getent passwd OLD`, brak starej grupy, `visudo -cf /etc/sudoers` oraz `sudo -l -U NEW`. Zaloguj sie jako nowy uzytkownik.

## Test funkcjonalnosci

**PASS**: UID i pliki uzytkownika zachowane zgodnie z zalozeniem, nowa tozsamosc dziala, stara nie, a sudoers jest poprawny.


