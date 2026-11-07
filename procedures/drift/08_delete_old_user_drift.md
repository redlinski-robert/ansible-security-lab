# D08 - delete_old_user.yml

## Cel testu
Potwierdzenie, ze recznie odtworzone konto, ktorego stan docelowy to `absent`, jest ponownie usuwane.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/delete_old_user.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/delete_old_user.yml --limit edge -e 'old_user=drift-old-user'
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "useradd -m -s /bin/bash drift-old-user; printf 'drift-old-user ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/drift-old-user-user; chmod 0440 /etc/sudoers.d/drift-old-user-user"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "id drift-old-user; ls -l /etc/sudoers.d/drift-old-user-user"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/delete_old_user.yml --limit edge -e 'old_user=drift-old-user'
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "id drift-old-user || echo USER_ABSENT; test ! -e /etc/sudoers.d/drift-old-user-user && echo SUDOERS_ABSENT; test ! -d /home/drift-old-user && echo HOME_ABSENT"
```

## Kryteria zaliczenia
- przed remediacja konto i sudoers istnieja,
- po playbooku konto, home i prywatny sudoers nie istnieja.