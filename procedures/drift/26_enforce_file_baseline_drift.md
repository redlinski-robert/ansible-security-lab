# D26 - enforce_file_baseline.yml

## Cel testu
Potwierdzenie, ze zmiana uprawnien pliku objetego `permission_baseline` jest naprawiana.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/enforce_file_baseline.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_file_baseline.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "chmod 0666 /etc/ssh/sshd_config"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "stat -c '%a %U %G %n' /etc/ssh/sshd_config"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_file_baseline.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "stat -c '%a %U %G %n' /etc/ssh/sshd_config"
```

## Kryteria zaliczenia
- przed remediacja tryb wynosi `0666`;
- po baseline wraca do `0600 root root`;
- raport nie pokazuje rozbieznosci dla tej sciezki.
