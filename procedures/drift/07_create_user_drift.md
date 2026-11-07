# D07 - create_user.yml

## Cel testu
Potwierdzenie, ze playbook naprawia parametry juz istniejacego konta testowego.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/create_user.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/create_user.yml --limit edge -e 'username=drift-test-user groupname=drift-test-group sudo_access_method=none'
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "usermod -s /bin/sh drift-test-user; chmod 0755 /home/drift-test-user/.ssh"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "getent passwd drift-test-user; stat -c '%a %U %G %n' /home/drift-test-user/.ssh"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/create_user.yml --limit edge -e 'username=drift-test-user groupname=drift-test-group sudo_access_method=none'
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "getent passwd drift-test-user; stat -c '%a %U %G %n' /home/drift-test-user/.ssh"
```

## Kryteria zaliczenia
- przed remediacja shell to `/bin/sh`, `.ssh` ma `0755`,
- po remediacji shell wraca do `/bin/bash`, `.ssh` do `0700`.
