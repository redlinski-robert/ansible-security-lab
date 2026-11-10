# D02 - change_netplan.yml

## Cel testu
Potwierdzenie, ze zmieniony recznie DNS oraz tryb pliku Netplan sa przywracane zgodnie z template i baseline uprawnien.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/change_netplan.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/change_netplan.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i 's/8\.8\.8\.8/9.9.9.9/' /etc/netplan/99-ansible-dns.yaml; chmod 0644 /etc/netplan/99-ansible-dns.yaml"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -nE '8\.8\.8\.8|9\.9\.9\.9|1\.1\.1\.1' /etc/netplan/99-ansible-dns.yaml; stat -c '%a %U %G %n' /etc/netplan/99-ansible-dns.yaml"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/change_netplan.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -nE '8\.8\.8\.8|1\.1\.1\.1' /etc/netplan/99-ansible-dns.yaml; stat -c '%a %U %G %n' /etc/netplan/99-ansible-dns.yaml; getent ahosts security.ubuntu.com | head"
```

## Kryteria zaliczenia
- `9.9.9.9` znika,
- wracaja `8.8.8.8` i `1.1.1.1`,
- tryb pliku wraca do `0600`,
- DNS dziala po remediacji.

## Uwagi
Nie zmieniaj trasy domyslnej ani nazwy interfejsu - do testu dryftu nie jest to potrzebne i zwieksza ryzyko utraty lacznosci.
