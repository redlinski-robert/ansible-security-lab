# D09 - install_docker.yml

## Cel testu
Potwierdzenie, ze recznie zatrzymana i wylaczona usluga Docker jest przywracana do stanu `started/enabled`.

## Zakres
- Host / zakres testowy: `app`
- Playbook remediacyjny: `playbooks/install_docker.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_docker.yml --limit app
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "systemctl disable --now docker"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "systemctl is-enabled docker || true; systemctl is-active docker || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_docker.yml --limit app
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "systemctl is-enabled docker; systemctl is-active docker; docker --version; docker compose version"
```

## Kryteria zaliczenia
- przed remediacja Docker jest `disabled`/`inactive`,
- po playbooku jest `enabled`/`active`,
- Docker i Compose odpowiadaja.