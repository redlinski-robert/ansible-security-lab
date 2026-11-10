# D04 - add_security_banner.yml

## Cel testu
Potwierdzenie, ze zmieniona recznie tresc banera SSH i jego uprawnienia sa przywracane przez playbook.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/add_security_banner.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/add_security_banner.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "printf 'DRIFT_TEST\n' > /etc/issue.net; chmod 0666 /etc/issue.net"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "cat /etc/issue.net; stat -c '%a %U %G' /etc/issue.net"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/add_security_banner.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n 'UWAGA! SYSTEM CHRONIONY' /etc/issue.net; stat -c '%a %U %G' /etc/issue.net; grep -E '^Banner|^UsePAM' /etc/ssh/sshd_config"
```

## Kryteria zaliczenia
- przed remediacja widoczny jest `DRIFT_TEST` i tryb `0666`,
- po remediacji wraca tresc banera,
- `/etc/issue.net` ma `0644 root root`.
