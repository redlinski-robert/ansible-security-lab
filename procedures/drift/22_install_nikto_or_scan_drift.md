# D22 - install_nikto_or_scan.yml

## Cel testu
Potwierdzenie, ze usuniety Nikto jest ponownie instalowany przed skanowaniem.

## Zakres
- Host / zakres testowy: `scanner`
- Playbook remediacyjny: `playbooks/install_nikto_or_scan.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

> **Warunek wstepny:** `nikto_input_file` moze pochodzic z wczesniejszego uruchomienia Nmap, ale jego brak nie blokuje testu - playbook ma sciezke zapasowa budujaca cele z inventory.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nikto_or_scan.yml --limit scanner
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "apt-mark unhold nikto || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nikto"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "command -v nikto || echo NIKTO_ABSENT; dpkg-query -W nikto || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nikto_or_scan.yml --limit scanner
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "nikto -Version 2>&1 | head; dpkg --get-selections nikto"
```

## Kryteria zaliczenia
- przed remediacja Nikto jest nieobecny;
- po playbooku jest ponownie zainstalowany i dostepny.

## Uwagi
Skan kieruj wylacznie do hostow blue w tym laboratorium.
