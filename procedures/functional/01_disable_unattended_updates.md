# F01 - disable_unattended_updates.yml

Uruchom playbook. Z maszyny `management` sprawdz stan uslugi i ustawienia APT, ktore kontroluja automatyczne aktualizacje.

## 1) Test aktywnosci uslugi unattended-upgrades

```bash
ansible all -b -m command -a "systemctl is-active unattended-upgrades.service"
```

Wyjasnienie: `systemctl is-active` sprawdza, czy usluga aktualizacji dziala w tej chwili. Oczekiwany wynik to `inactive` albo, na hoscie bez zainstalowanej uslugi, `not-found`.

## 2) Test uruchamiania uslugi przy starcie

```bash
ansible all -b -m command -a "systemctl is-enabled unattended-upgrades.service"
```

Wyjasnienie: `systemctl is-enabled` sprawdza, czy usluga zostanie uruchomiona przy starcie systemu. Oczekiwany wynik to `disabled` albo `not-found`.

## 3) Test konfiguracji APT Periodic

```bash
ansible all -b -m shell -a "apt-config dump | grep -E 'APT::Periodic::(Enable|Update-Package-Lists|Unattended-Upgrade)'"
```

Wyjasnienie: `apt-config dump` odczytuje efektywna konfiguracje APT, a `grep` pokazuje tylko dyrektywy odpowiedzialne za automatyczne aktualizacje. Sprawdz, czy wartosci sa ustawione na `0`.

## 4) Test pliku ustawien APT

```bash
ansible all -b -m command -a "cat /etc/apt/apt.conf.d/20auto-upgrades"
```

Wyjasnienie: `cat` pokazuje zawartosc pliku, ktory zapisuje ustawienia okresowych aktualizacji. Oczekuj wartosci `"0"` dla `APT::Periodic::Update-Package-Lists` oraz `APT::Periodic::Unattended-Upgrade`.

W `/etc/apt/apt.conf.d/20auto-upgrades` oczekuj wartosci `"0"` dla `APT::Periodic::Update-Package-Lists` oraz `APT::Periodic::Unattended-Upgrade`.

Kody `rc=3` dla `inactive`, `rc=1` dla `disabled` i `rc=4` dla `not-found` sa oczekiwanymi stanami `systemctl`. Ansible moze je oznaczyc jako `FAILED`, mimo ze test przeszedl. Na scannerze brak uslugi (`not-found`) jest poprawny.

## 5) Test potwierdzajacy, ze uslugi nie wroca po restarcie

```bash
ansible all -b -m command -a "systemctl is-active apt-daily.timer"
ansible all -b -m command -a "systemctl is-active apt-daily-upgrade.timer"
ansible all -b -m command -a "systemctl is-active apt-daily.service"
ansible all -b -m command -a "systemctl is-active apt-daily-upgrade.service"
ansible all -b -m command -a "systemctl is-active unattended-upgrades.service"
ansible all -b -m command -a "systemctl is-enabled apt-daily.timer"
ansible all -b -m command -a "systemctl is-enabled apt-daily-upgrade.timer"
ansible all -b -m command -a "systemctl is-enabled apt-daily.service"
ansible all -b -m command -a "systemctl is-enabled apt-daily-upgrade.service"
ansible all -b -m command -a "systemctl is-enabled unattended-upgrades.service"
```

Wyjasnienie: `systemctl is-active` sprawdza, czy jednostka jest obecnie uruchomiona. Wszystkie istniejace jednostki powinny zwrocic `inactive`, a brakujaca usluga `not-found`. `systemctl is-enabled` sprawdza, czy jednostka uruchomi sie przy starcie. Timery oraz `unattended-upgrades.service` powinny zwrocic `disabled` albo `not-found`. Uslugi `apt-daily.service` i `apt-daily-upgrade.service` moga zwrocic `static`, poniewaz nie sa przeznaczone do samodzielnego wlaczania i sa uruchamiane przez timery. Jesli timer lub usluga unattended-upgrades zwroci `enabled`, blokada nie dziala w pelni.



## Test funkcjonalnosci

**PASS**: uslugi nie dzialaja, timery i `unattended-upgrades.service` nie uruchomia sie przy starcie, uslugi statyczne pozostaja `static`, APT Periodic jest wylaczony, a uslugi APT sa zablokowane przed restartem systemu.


