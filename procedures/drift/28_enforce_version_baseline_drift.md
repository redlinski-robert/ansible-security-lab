# D28 - enforce_version_baseline.yml

## Cel testu
Potwierdzenie, ze brak pakietu ujetego w baseline wersji jest naprawiany do wersji z inventory.

## Zakres
- Host / zakres testowy: `scanner`
- Playbook remediacyjny: `playbooks/enforce_version_baseline.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_version_baseline.yml --limit scanner
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "apt-mark unhold nmap || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nmap"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' nmap || echo NMAP_ABSENT"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_version_baseline.yml --limit scanner
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible scanner -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' nmap; dpkg --get-selections nmap"
```

## Kryteria zaliczenia
- przed remediacja Nmap jest nieobecny;
- po baseline jest w wersji `7.99+dfsg-1kali1`;
- hold jest odtworzony;
- raport nie wskazuje rozbieznosci dla Nmap.