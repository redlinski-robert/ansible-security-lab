# D18 - install_fail2ban.yml

## Cel testu
Potwierdzenie, ze reczna zmiana `maxretry` w `jail.local` jest przywracana z template.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_fail2ban.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_fail2ban.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i -E 's/^maxretry[[:space:]]*=.*/maxretry  = 99/' /etc/fail2ban/jail.local"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n '^maxretry' /etc/fail2ban/jail.local"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_fail2ban.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n '^maxretry' /etc/fail2ban/jail.local; systemctl is-active fail2ban; fail2ban-client status sshd"
```

## Kryteria zaliczenia
- przed remediacja `maxretry = 99`;
- po remediacji `maxretry = 3`;
- Fail2Ban dziala i jail `sshd` jest aktywny.