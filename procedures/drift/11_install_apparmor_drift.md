# D11 - install_apparmor.yml

## Cel testu
Potwierdzenie, ze recznie zatrzymany i wylaczony AppArmor zostaje ponownie uruchomiony i wlaczony.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/install_apparmor.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_apparmor.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "systemctl disable --now apparmor"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "systemctl is-enabled apparmor || true; systemctl is-active apparmor || true"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/install_apparmor.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "systemctl is-enabled apparmor; systemctl is-active apparmor; aa-status | head -n 8"
```

## Kryteria zaliczenia
- przed remediacja AppArmor nie jest aktywny,
- po remediacji jest `enabled` i `active`,
- `aa-status` potwierdza dzialanie.
