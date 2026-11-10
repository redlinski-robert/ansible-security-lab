# D25 - install_zabbix_get_or_test_zabbix_agent.yml

## Cel testu
Potwierdzenie remediacji brakujacego `zabbix_get` na kontrolerze oraz poprawnego rollbacku tymczasowej konfiguracji agenta.

## Zakres
- Host / zakres testowy: `edge,localhost`
- Playbook remediacyjny: `playbooks/install_zabbix_get_or_test_zabbix_agent.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_zabbix_get_or_test_zabbix_agent.yml --limit edge,localhost
```

### 2. Wprowadz kontrolowany dryft
```bash
sudo apt-get remove -y zabbix-get
```

### 3. Potwierdz wystapienie dryftu
```bash
command -v zabbix_get || echo ZABBIX_GET_ABSENT
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_zabbix_get_or_test_zabbix_agent.yml --limit edge,localhost
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
zabbix_get --version
ansible edge -i inventories/hosts.yml -b -m shell -a "grep '^Server=' /etc/zabbix/zabbix_agent2.conf; find /etc/zabbix/ansible-backup -maxdepth 1 -type f -print 2>/dev/null || true"
```

## Kryteria zaliczenia
- przed remediacja `zabbix_get` jest nieobecny;
- po playbooku binarka dziala;
- `agent.ping` przechodzi;
- tymczasowa zmiana `Server=` zostaje cofnieta i nie pozostaje backup.

## Uwagi
Pierwsza czesc playbooka dziala na localhost, druga na blue_group, dlatego nie ograniczaj go wylacznie do `edge` bez `localhost`.
