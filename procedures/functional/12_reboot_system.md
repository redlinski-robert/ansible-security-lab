# F12 - reboot_system.yml

Uruchom playbook (zazwyczaj jako ostatni w sekwencji, gdy wymagane sa zmiany w kernelu lub systemowe). Z maszyny `management` sprawdz:
Czas uruchomienia powinien byc zblizony do momentu testowania, a `systemctl --failed` nie powinien wskazywac uslug w stanie failed.

Wez pod uwage:
- `systemctl status` - wszystkie uslugi powinny byc dostepne w normalnym stanie
- Polaczenie sieciowe - jesli host mial reguly firewall, powinien byc dostepny ponownie
- Baseline checks - jesli sa dostepne, sprawdz czy konfiguracje przetrwaly restart
## 1) Test dostepnosci hostow po restarcie

```bash
ansible all -m ping
```

Wyjasnienie: modul `ping` sprawdza, czy host odpowiada po restarcie i czy Ansible moze ponownie nawiazac polaczenie.

## 2) Test czasu pracy systemu

```bash
ansible all -b -m command -a "uptime"
```

Wyjasnienie: `uptime` pokazuje czas od uruchomienia systemu. swiezy czas pracy potwierdza, ze host rzeczywiscie wykonal restart.

## 3) Test uslug zakonczonych bledem

```bash
ansible all -b -m command -a "systemctl --failed"
```

Wyjasnienie: `systemctl --failed` wyswietla uslugi, ktore po starcie systemu zakonczyly sie bledem. Oczekiwany jest pusty wynik.

## Test funkcjonalnosci

**PASS**: system sie poprawnie zrestartowal, uslugi funkcjonuja, konfiguracja jest zachowana. Ten test jest zalezny od kontekstu i powinien byc ostatnia operacja w sekwencji.


