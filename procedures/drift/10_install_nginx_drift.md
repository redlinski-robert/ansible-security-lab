# D10 - install_nginx.yml

## Cel testu
Potwierdzenie, ze recznie zmieniona konfiguracja reverse proxy jest nadpisywana szablonem Ansible.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_nginx.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nginx.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "echo '# DRIFT_TEST' >> /etc/nginx/sites-available/mojeansible.pl.conf"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "tail -n 3 /etc/nginx/sites-available/mojeansible.pl.conf; nginx -t"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nginx.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n DRIFT_TEST /etc/nginx/sites-available/mojeansible.pl.conf || echo DRIFT_USUNIETY; nginx -t; systemctl is-active nginx"
```

## Kryteria zaliczenia
- przed remediacja znacznik jest obecny,
- po playbooku znika,
- `nginx -t` i usluga Nginx sa poprawne.