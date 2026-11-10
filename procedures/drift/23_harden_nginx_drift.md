# D23 - harden_nginx.yml

## Cel testu
Potwierdzenie, ze reczne przelaczenie ModSecurity z `On` na `DetectionOnly` jest przywracane przez hardening.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/harden_nginx.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_nginx.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i -E 's/^SecRuleEngine[[:space:]]+.*/SecRuleEngine DetectionOnly/' /etc/nginx/modsecurity/modsecurity.conf"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n '^SecRuleEngine' /etc/nginx/modsecurity/modsecurity.conf; nginx -t"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_nginx.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -n '^SecRuleEngine' /etc/nginx/modsecurity/modsecurity.conf; test -f /etc/nginx/conf.d/10-security-headers.conf && echo HEADERS_OK; nginx -t; systemctl is-active nginx"
```

## Kryteria zaliczenia
- przed remediacja `SecRuleEngine DetectionOnly`;
- po remediacji `SecRuleEngine On`;
- `nginx -t` przechodzi i Nginx dziala.
