# D19 - configure_firewall.yml

## Cel testu
Potwierdzenie, ze reczne wylaczenie logowania UFW jest przywracane przez baze regul.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/configure_firewall.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/configure_firewall.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "ufw logging off"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "ufw status verbose"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/configure_firewall.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "ufw status verbose"
```

## Kryteria zaliczenia
- przed remediacja `Logging: off`;
- po remediacji logowanie jest `on`;
- polityki default pozostaja `deny incoming` / `allow outgoing`.
