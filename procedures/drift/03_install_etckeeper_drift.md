# D03 - install_etckeeper.yml

## Cel testu
Potwierdzenie, ze reczna modyfikacja zarzadzanego `/etc/etckeeper/etckeeper.conf` jest nadpisywana plikiem wzorcowym.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_etckeeper.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_etckeeper.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "echo '# DRIFT_TEST' >> /etc/etckeeper/etckeeper.conf"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "tail -n 3 /etc/etckeeper/etckeeper.conf; grep -n DRIFT_TEST /etc/etckeeper/etckeeper.conf"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_etckeeper.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n DRIFT_TEST /etc/etckeeper/etckeeper.conf || echo DRIFT_USUNIETY; git -C /etc config user.name; git -C /etc config user.email; git -C /etc log -1 --oneline"
```

## Kryteria zaliczenia
- znacznik `DRIFT_TEST` jest widoczny przed remediacja,
- po playbooku znika,
- konfiguracja Git dla `/etc` pozostaje poprawna.