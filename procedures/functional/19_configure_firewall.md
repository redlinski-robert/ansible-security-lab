# F19 - configure_firewall.yml

Po uruchomieniu playbooka, z maszyny `management` zapisz stan firewalla i sprawdz rzeczywiste przeplywy sieciowe.

## Referencyjna lista portow w labzie

| Usluga | Zmienna/Lokacja | Default | Opis |
|--------|-----------------|---------|------|
| SSH (domyslny) | `ansible_port` | 22 | SSH na wszystkich hostach (management, edge, app) |
| SSH (custom edge) | `harden_ssh.yml:12` | 2228 | SSH na edge po uruchomieniu harden_ssh |
| Zabbix Agent | `zabbix_agent_port` | 10050 | Zabbix agent na edge i app (z management) |
| HTTPS nginx | `https_port` | 443 | HTTPS na edge (z desktop/lab, NAT gateway) |
| HTTP nginx | - | 80 | HTTP redirect na edge (z desktop/lab) |
| Frontend aplikacji | `frontend_port` | 8443 | Frontend app na app (z edge) |
| Backend Docker | - | 5000 | Backend Docker na app (z edge, blokowany dla pozostalych) |

**Uwaga:** Porty 8443 i 5000 (aplikacja) beda testowalne dopiero po uruchomieniu `deploy_application.yml`. Do czasu zainstalowania aplikacji beda pokazywac "Connection refused".

## 1) Test stanu UFW

```bash
ansible blue_group -b -m command -a "ufw status verbose"
```

Wyjasnienie: `ufw status verbose` pokazuje, czy firewall jest aktywny oraz jakie polityki sa wlaczone. To jest najwazniejsza kontrola, zeby upewnic sie, ze reguly zostaly zaladowane i nie sa w stanie nieaktywnym.

## 2) Test kolejnosci regul UFW

```bash
ansible blue_group -b -m command -a "ufw status numbered"
```

Wyjasnienie: `ufw status numbered` pokazuje kolejnosc regul w firewallze. To wazne, bo w polityce sieciowej kolejnosc ma znaczenie: pozwolenia i blokady musza byc ulozone w odpowiedniej hierarchii, aby nie zostaly zignorowane przez wczesniejsze reguly.

## 3) Test regul Docker-USER

```bash
ansible app_servers -b -m shell -a "iptables -S DOCKER-USER"
```

Wyjasnienie: ta komenda sprawdza dodatkowa warstwe regul dla Docker. Pozwala potwierdzic, ze szczegolne przeplywy do kontenerow sa kontrolowane osobno i nie omijaja polityki firewalla podstawowego.

## 4) Test aktywnych portow i nasluchu

```bash
ansible blue_group -b -m command -a "ss -lntup"
```

Wyjasnienie: `ss -lntup` pokazuje, ktore porty sa aktywnie nasluchiwane i przez jakie procesy. To pozwala sprawdzic, czy firewall otworzyl tylko wlasciwe uslugi i czy nie ma niepotrzebnych portow publicznie dostepnych.

## 5) Test polaczenia z hosta zrodlowego

```bash
ansible HOST_ZRODLOWY -m shell -a "nc -vz -w 3 CEL PORT"
```

Wyjasnienie: ta komenda sprawdza realny ruch sieciowy miedzy hostami i uslugami. Potwierdza, czy dozwolone polaczenie rzeczywiscie przechodzi i czy droga sieciowa dziala zgodnie z polityka firewalla.

## 6) Test odpowiedzi HTTP/S z poziomu sieci

```bash
ansible HOST_ZRODLOWY -m shell -a "curl -k --connect-timeout 5 URL"
```

Wyjasnienie: to sprawdza, czy usluga odpowiada po wejsciu z sieci i czy polaczenie jest faktycznie dostepne dla poprawnych zrodel. To jest test funkcjonalny, ktory pokazuje skutecznosc regul w praktyce, a nie tylko ich obecnosc w konfiguracji.

**PASS dla stanu**: UFW `active`, incoming `deny`, outgoing `allow`, logging `on`, a kolejnosc DOCKER-USER to ESTABLISHED/RELATED, allow z edge do TCP/5000, potem drop pozostalych do 5000.

## Testy przeplywow

Testy przeplywow uruchamiaj z `management` przez `ansible HOST_ZRODLOWY -m shell -a "nc -vz -w 3 CEL PORT"` lub `ansible HOST_ZRODLOWY -m shell -a "curl -k --connect-timeout 5 URL"`:

| zrodlo → cel | Port | Oczekiwane |
|---|---:|---|
| desktop/lab → edge | 80, 443, 2228 | allow |
| management → edge/app | 10050 | allow |
| edge → app | 8443 i 5000 | allow |
| scanner → edge/app | zgodnie z `let_scanner_hosts_connect` | allow albo deny |
| scanner/inna maszyna → app | 5000 | deny |
| dowolne nieuprawnione zrodlo → blue | niezadeklarowany port | deny |

**FAIL**: Po ponownym uruchomieniu hosta powtorz test DOCKER-USER; obecny playbook nie zapisuje regul iptables w trwalym mechanizmie, wiec utrata regul po reboot oznacza FAIL dla trwalosci segmentacji.

## Test funkcjonalnosci


**PASS**: wymaga zarowno udanych polaczen dozwolonych, jak i nieudanych zabronionych. Sam `nmap` z jednego hosta nie wystarcza.

