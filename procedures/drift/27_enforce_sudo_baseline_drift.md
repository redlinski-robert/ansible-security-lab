# D27 - enforce_sudo_baseline.yml

## Cel testu
Potwierdzenie, ze zmieniony zarzadzany wpis sudoers jest przywracany zgodnie z centralnym baseline.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/enforce_sudo_baseline.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_sudo_baseline.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "printf 'ansible ALL=(ALL) ALL\n' > /etc/sudoers.d/ansible-user; chmod 0440 /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers.d/ansible-user"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "cat /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers.d/ansible-user"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/enforce_sudo_baseline.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "cat /etc/sudoers.d/ansible-user; stat -c '%a %U %G' /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers; sudo -l -U ansible"
```

## Kryteria zaliczenia
- przed remediacja wpis nie zawiera `NOPASSWD`;
- po playbooku jest `ansible ALL=(ALL) NOPASSWD:ALL`;
- plik ma `0440 root root`;
- `visudo -cf /etc/sudoers` przechodzi.

