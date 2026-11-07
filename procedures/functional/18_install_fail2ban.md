# F18 - install_fail2ban.yml

Uruchom playbook. Z maszyny `management` wykonaj:



Wykonaj kilka nieudanych logowan SSH (np. `ssh -u root@HOST` z blednym haslem), obserwuj logi `tail -f /var/log/fail2ban.log` i `iptables -L -n | grep fail2ban`.
## 1) Test zainstalowania pakietu fail2ban

```bash
ansible blue_group -b -m command -a "dpkg-query -W fail2ban"
```

Wyjasnienie: ta komenda sprawdza, czy pakiet fail2ban jest zainstalowany. Bez pakietu nie ma narzedzi do monitorowania i blokowania nieudanych prob logowania.

## 2) Test aktywacji uslugi fail2ban

```bash
ansible blue_group -b -m shell -a "systemctl is-enabled fail2ban"
```

Wyjasnienie: `is-enabled` pokazuje, czy fail2ban ma byc uruchamiany automatycznie przy starcie systemu. To zapewnia trwalosc ochrony przed atakami brute-force nawet po restarcie hosta.

## 3) Test aktywnosci uslugi fail2ban

```bash
ansible blue_group -b -m shell -a "systemctl is-active fail2ban"
```

Wyjasnienie: ta komenda sprawdza, czy daemon fail2ban faktycznie dziala. Samo zainstalowanie i skonfigurowanie uslugi nie daje ochrony, jesli proces nie jest uruchomiony.

## 4) Test statusu fail2ban

```bash
ansible blue_group -b -m command -a "fail2ban-client status"
```

Wyjasnienie: to pokazuje ogolny stan fail2ban i aktywne jails. To pozwala sprawdzic, czy daemon nie ma bledow i czy wczesniej skonfigurowane mechanizmy ochrony sa aktywne.

## 5) Test statusu jail sshd

```bash
ansible blue_group -b -m command -a "fail2ban-client status sshd"
```

Wyjasnienie: ta komenda sprawdza konkretna jaile `sshd`, czyli ochrone dla logowan SSH. To najwazniejsza kontrola, bo pokazuje, czy zabezpieczenie jest aktywne dla danych wejsc, ktore maja byc filtrowane.

## Test funkcjonalnosci

**PASS**: usluga dziala i jest wlaczona przy starcie, co najmniej jedna jail (np. `sshd`) jest aktywna, a nieudane logowania powoduja blokade IP. Drugi przebieg nie zmienia konfiguracji.


