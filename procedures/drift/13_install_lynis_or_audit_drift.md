# D13 - install_lynis_or_audit.yml

## Cel testu
Potwierdzenie, ze recznie usuniety Lynis jest ponownie instalowany zgodnie z baseline.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_lynis_or_audit.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_lynis_or_audit.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "apt-mark unhold lynis || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y lynis"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' lynis || echo LYNIS_ABSENT"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_lynis_or_audit.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' lynis; dpkg --get-selections lynis"
```

## Kryteria zaliczenia
- przed remediacja Lynis jest nieobecny,
- po playbooku jest ponownie zainstalowany i objety hold,
- audyt wykonuje sie poprawnie.
