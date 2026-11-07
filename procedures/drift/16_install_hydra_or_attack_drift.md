# D16 - install_hydra_or_attack.yml

## Cel testu
Potwierdzenie, ze usunieta Hydra jest odtwarzana przed kontrolowanym testem w labie.

## Zakres
- Host / zakres testowy: `scanner`
- Playbook remediacyjny: `playbooks/install_hydra_or_attack.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

> **Warunek wstepny:** przy domyslnym `get_rotated_passwords: true` playbook wymaga plikow utworzonych przez `rotate_passwords.yml`. Jezeli ich nie ma, najpierw wykonaj `playbooks/rotate_passwords.yml`. Input z Nmap jest opcjonalny, poniewaz przy jego braku playbook buduje cele z inventory.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_hydra_or_attack.yml --limit scanner
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "apt-mark unhold hydra || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y hydra"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "command -v hydra || echo HYDRA_ABSENT; dpkg-query -W hydra || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_hydra_or_attack.yml --limit scanner
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "hydra -h 2>&1 | head -n 2; dpkg --get-selections hydra"
```

## Kryteria zaliczenia
- przed remediacja Hydra jest nieobecna,
- po playbooku jest ponownie zainstalowana.
