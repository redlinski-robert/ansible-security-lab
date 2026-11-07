# F25 - install_zabbix_get_or_test_zabbix_agent.yml

Ten playbook dziala na `management`. Po uruchomieniu sprawdz lokalnie:



Zastap `AGENT_IP` adresem agenta Zabbix.

Uruchom lokalnie na kontrolerze Ansible:

`ansible-playbook playbooks/install_zabbix_get.yml -e zabbix_branch=7.0`

Playbook obsluguje Ubuntu 20.04/22.04/24.04, instaluje repozytorium Zabbix i pakiet `zabbix-get`.
Po wykonaniu sprawdz:

`zabbix_get --version`

Przykladowe testy:

`zabbix_get -s __UZUPELNIJ_IP_APP__ -k agent.ping`

`zabbix_get -s __UZUPELNIJ_IP_APP__ -k system.uptime`
## 1) Test wersji zabbix_get

```bash
zabbix_get --version
```

Wyjasnienie: `zabbix_get --version` potwierdza, ze narzedzie zostalo zainstalowane lokalnie i mozna je uruchomic na kontrolerze Ansible.

## 2) Test odpowiedzi agenta Zabbix

```bash
zabbix_get -s AGENT_IP -p 10050 -k agent.ping
```

Wyjasnienie: zapytanie `agent.ping` sprawdza, czy agent Zabbix przyjmuje polaczenia na porcie `10050` i odpowiada na podstawowy klucz monitoringu.

## 3) Test odczytu metryki agenta

```bash
zabbix_get -s AGENT_IP -p 10050 -k system.uptime
```

Wyjasnienie: zapytanie `system.uptime` sprawdza odczyt rzeczywistej metryki z agenta. Potwierdza, ze komunikacja dziala nie tylko dla testowego `agent.ping`, ale takze dla danych monitorowanych.

## 4) Test nazwy hosta agenta

```bash
zabbix_get -s AGENT_IP -p 10050 -k system.hostname
```

Wyjasnienie: zapytanie `system.hostname` potwierdza, ze agent odpowiada na dodatkowy klucz i identyfikuje wlasciwy host. Dla `edge` i `app` wynik powinien odpowiadac nazwie hosta ustawionej w konfiguracji agenta.

## 5) Test dostepnych zasobow systemowych

```bash
zabbix_get -s AGENT_IP -p 10050 -k vm.memory.size[available]
zabbix_get -s AGENT_IP -p 10050 -k vfs.fs.size[/,free]
```

Wyjasnienie: te zapytania sprawdzaja odczyt dostepnej pamieci oraz wolnego miejsca na glownym systemie plikow. Oba wyniki powinny byc wartosciami liczbowymi wiekszymi lub rownymi zero.

## Test funkcjonalnosci


**PASS**: `agent.ping`, `system.uptime`, `system.hostname`, dostepna pamiec i wolne miejsce na `/` sa poprawnie odczytywane z agentow na porcie `10050`, a narzedzie jest dostepne na maszynie wykonujacej test.
