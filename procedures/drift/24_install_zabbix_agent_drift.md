# D24 - install_zabbix_agent.yml

## Cel testu
Potwierdzenie, ze zmieniony `Server=` i zatrzymany agent Zabbix sa naprawiane.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_zabbix_agent.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_zabbix_agent.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i -E 's/^Server=.*/Server=127.0.0.1/' /etc/zabbix/zabbix_agent2.conf; systemctl stop zabbix-agent2"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -E '^(Hostname|Server|ServerActive)=' /etc/zabbix/zabbix_agent2.conf; systemctl is-active zabbix-agent2 || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_zabbix_agent.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -E '^(Hostname|Server|ServerActive)=' /etc/zabbix/zabbix_agent2.conf; systemctl is-enabled zabbix-agent2; systemctl is-active zabbix-agent2; zabbix_agent2 -t agent.ping"
```

## Kryteria zaliczenia
- przed remediacja `Server=127.0.0.1` i agent jest zatrzymany;
- po remediacji `Server=__UZUPELNIJ_IP_KONTROLERA__`, `ServerActive=` jest pusty, a agent dziala.
