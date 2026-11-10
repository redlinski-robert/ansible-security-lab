# D15 - install_nmap_or_enumerate.yml

## Cel testu
Potwierdzenie, ze usuniety Nmap jest odtwarzany przed wykonaniem enumeracji.

## Zakres
- Host / zakres testowy: `scanner`
- Playbook remediacyjny: `playbooks/install_nmap_or_enumerate.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nmap_or_enumerate.yml --limit scanner
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "apt-mark unhold nmap || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nmap"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "command -v nmap || echo NMAP_ABSENT; dpkg-query -W nmap || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_nmap_or_enumerate.yml --limit scanner
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "nmap --version | head -n 1; dpkg --get-selections nmap; ls -ld /tmp/nmap_results"
```

## Kryteria zaliczenia
- przed remediacja Nmap jest nieobecny,
- po playbooku jest zainstalowany i dziala,
- enumeracja moze wygenerowac raport.
