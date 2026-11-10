# D01 - disable_unattended_updates.yml

## Cel testu
Potwierdzenie, ze reczna zmiana ustawienia automatycznych aktualizacji jest przywracana do wartosci zarzadzanej przez Ansible.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/disable_unattended_updates.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/disable_unattended_updates.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "sed -i 's/APT::Periodic::Unattended-Upgrade \"0\";/APT::Periodic::Unattended-Upgrade \"1\";/' /etc/apt/apt.conf.d/20auto-upgrades"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -E 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade)' /etc/apt/apt.conf.d/20auto-upgrades"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/disable_unattended_updates.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "grep -E 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade)' /etc/apt/apt.conf.d/20auto-upgrades; systemctl is-active unattended-upgrades.service || true"
```

## Kryteria zaliczenia
- przed remediacja `Unattended-Upgrade` ma wartosc `1`,
- po remediacji obie zarzadzane wartosci maja `0`,
- usluga `unattended-upgrades` nie jest aktywna.