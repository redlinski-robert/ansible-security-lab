# D17 - harden_ssh.yml

## Cel testu
Potwierdzenie, ze oslabienie parametru SSH bez zmiany portu zarzadzajacego jest naprawiane.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/harden_ssh.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_ssh.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i -E 's/^#?MaxAuthTries[[:space:]]+.*/MaxAuthTries 6/' /etc/ssh/sshd_config; sshd -t; systemctl reload ssh"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sshd -T | grep -E 'maxauthtries|allowtcpforwarding|x11forwarding|loglevel'"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_ssh.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sshd -T | grep -E 'maxauthtries|allowtcpforwarding|x11forwarding|loglevel'; sshd -t"
```

## Kryteria zaliczenia
- przed remediacja efektywne `maxauthtries` wynosi `6`;
- po remediacji wynosi `3`;
- `sshd -t` przechodzi poprawnie.