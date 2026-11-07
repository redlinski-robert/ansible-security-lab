# F24 - install_zabbix_agent.yml

Uruchom playbook. Z maszyny `management` sprawdz:



Jesli serwer Zabbix jest dostepny, sprawdz w interfejsie czy host pojawil sie i czy zbiera metryki.
## 1) Test zainstalowania agenta Zabbix

```bash
ansible blue_group -b -m command -a "dpkg-query -W zabbix-agent2"
```

Wyjasnienie: ta komenda sprawdza, czy pakiet agenta Zabbix jest zainstalowany. To jest podstawowa kontrola, bez ktorej nie ma mozliwosci monitorowania hosta przez serwer Zabbix.

## 2) Test wlaczenia uslugi agenta Zabbix

```bash
ansible blue_group -b -m shell -a "systemctl is-enabled zabbix-agent2"
```

Wyjasnienie: ta komenda sprawdza, czy agent ma byc uruchamiany automatycznie przy starcie systemu. To gwarantuje, ze monitorowanie bedzie aktywne po restarcie hosta.

## 3) Test aktywnosci uslugi agenta Zabbix

```bash
ansible blue_group -b -m shell -a "systemctl is-active zabbix-agent2"
```

Wyjasnienie: `is-active` sprawdza, czy daemon agenta faktycznie dziala. Bez tego agent nie bedzie odsylal metryk i serwer Zabbix nie uzyska danych o stanie hosta.

## 4) Test portu nasluchu agenta Zabbix

```bash
ansible blue_group -b -m shell -a "ss -lntup | grep zabbix"
```

Wyjasnienie: ta komenda pokazuje, czy agent nasluchuje na oczekiwanym porcie. To potwierdza, ze usluga jest gotowa do przyjmowania polaczen od serwera monitorujacego.

## 5) Test logow agenta Zabbix

```bash
ansible blue_group -b -m command -a "tail -n 30 /var/log/zabbix/zabbix_agent2.log"
```

Wyjasnienie: ta komenda czyta ostatnie wpisy z logow agenta. To pomaga wykryc bledy konfiguracji, problemy z polaczeniem do serwera lub nieprawidlowe dane zwracane przez agent.

## Test funkcjonalnosci

**PASS**: agent jest zainstalowany, usluga dziala i nasluchuje na porcie (domyslnie 10050), konfiguracja jest poprawna. Jesli zserver jest dostepny, host powinien byc widoczny z statusem "Available". Drugi przebieg nie reinstaluje agenta.


