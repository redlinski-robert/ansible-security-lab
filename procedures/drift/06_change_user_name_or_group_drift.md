# D06 - change_user_name_or_group.yml

## Cel testu
Potwierdzenie, ze kontrolowane cofniecie migracji testowego uzytkownika i grupy zostaje ponownie naprawione przez playbook.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/change_user_name_or_group.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
Najpierw utworz dedykowane konto i grupe wejsciowa, jezeli nie istnieja. Dzieki temu test nie zalezy od tego, czy wczesniej wykonano test `create_user.yml`.

```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "getent group my-test-group >/dev/null || groupadd my-test-group; id my-test-user >/dev/null 2>&1 || useradd -m -g my-test-group -s /bin/bash my-test-user"
ansible-playbook -i inventories/hosts.yml playbooks/change_user_name_or_group.yml --limit edge
```

Potwierdz stan docelowy przed wprowadzeniem dryftu:

```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "id my-new-user; getent group my-new-group; test -d /home/my-new-user && echo HOME_OK"
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "usermod -l my-test-user -d /home/my-test-user -m my-new-user; groupmod -n my-test-group my-new-group"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "id my-test-user; getent group my-test-group; id my-new-user || true; getent group my-new-group || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/change_user_name_or_group.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "id my-new-user; getent group my-new-group; test -d /home/my-new-user && echo HOME_OK"
```

## Kryteria zaliczenia
- przed remediacja istnieja `my-test-user` i `my-test-group`,
- po playbooku wracaja `my-new-user`, `my-new-group` i `/home/my-new-user`.

## Uwagi
Playbook jest migracyjny, wiec test wykonuj wylacznie na dedykowanych kontach testowych, nigdy na aktualnym uzytkowniku polaczenia Ansible.
