# D29 - rotate_passwords.yml

## Cel testu
Potwierdzenie remediacji trwalego inwariantu pliku hasla Vault (`0600`). Wartosc hasla nie jest stalym desired state, poniewaz kazda rotacja generuje nowa.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/rotate_passwords.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/rotate_passwords.yml -e 'password_target=edge'
```

### 2. Wprowadz kontrolowany dryft
```bash
chmod 0644 inventories/.vault_passwords/generated_admin_secrets.pass
```

### 3. Potwierdz wystapienie dryftu
```bash
stat -c '%a %U %G %n' inventories/.vault_passwords/generated_admin_secrets.pass
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/rotate_passwords.yml -e 'password_target=edge'
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
stat -c '%a %U %G %n' inventories/.vault_passwords/generated_admin_secrets.pass
head -n 1 inventories/host_vars/edge/secrets.pass
```

## Kryteria zaliczenia
- przed remediacja plik Vault ma `0644`;
- po playbooku wraca do `0600`;
- sekret hosta pozostaje zaszyfrowany (`$ANSIBLE_VAULT...`).

## Uwagi
W raporcie oznacz jako **czesciowy test dryftu / test inwariantu**. Nie oczekuj przywrocenia poprzedniej wartosci hasla.
