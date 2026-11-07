# F17 - harden_ssh.yml

Przed zmiana utrzymaj aktywna sesje awaryjna. Po uruchomieniu playbooka, z maszyny `management` wykonaj:



Oczekuj portu 2228, `maxauthtries 3`, obu forwardingow `no` i `loglevel VERBOSE`. `ansible all -m ping` potwierdza nowe polaczenie SSH z inventory.

Test negatywny: z `management` proba `ssh -L` i X11 nie moze zestawic forwardingu. Testuj tylko po potwierdzeniu, ze sesja awaryjna nadal dziala.
## 1) Test skladni konfiguracji SSH

```bash
ansible all -b -m command -a "sshd -t"
```

Wyjasnienie: `sshd -t` sprawdza skladnie konfiguracji bez uruchamiania demona. Brak komunikatu bledu oznacza, ze mozna bezpiecznie przejsc do sprawdzania efektywnych parametrow.

## 2) Test efektywnych parametrow SSH

```bash
ansible all -b -m shell -a "sshd -T | grep -E '^(port|maxauthtries|allowtcpforwarding|x11forwarding|loglevel)'"
```

Wyjasnienie: `sshd -T` pokazuje konfiguracje faktycznie uzywana przez demona, a `grep` ogranicza wynik do parametrow objetych hardeningiem. Sprawdz port `2228`, `maxauthtries 3`, oba forwardingi ustawione na `no` oraz `loglevel VERBOSE`.

## 3) Test polaczenia Ansible po zmianach

```bash
ansible all -m ping
```

Wyjasnienie: modul `ping` sprawdza, czy Ansible nadal moze uwierzytelnic sie i wykonac operacje na hostach po zmianie konfiguracji SSH. Ten test potwierdza dzialanie polaczenia z perspektywy automatyzacji, a nie tylko poprawnosc pliku konfiguracyjnego.

## Test funkcjonalnosci

**PASS**: efektywna konfiguracja, nie tylko linie w pliku, jest zgodna. Nowy port dziala, stary nie i automatyzacja nadal laczy sie z hostem.

