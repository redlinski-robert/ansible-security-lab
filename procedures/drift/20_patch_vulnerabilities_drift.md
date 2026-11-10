# D20 - patch_vulnerabilities.yml

## Cel testu
Potwierdzenie, ze brak pakietu objetego remediacja podatnosci jest naprawiany do wersji baseline.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/patch_vulnerabilities.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/patch_vulnerabilities.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "apt-mark unhold vim || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y vim"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' vim || echo VIM_ABSENT"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/patch_vulnerabilities.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' vim vim-common vim-runtime policykit-1; dpkg --get-selections vim"
```

## Kryteria zaliczenia
- przed remediacja `vim` jest nieobecny;
- po playbooku pakiety z zakresu sa obecne w wersjach baseline;
- hold jest odtworzony.