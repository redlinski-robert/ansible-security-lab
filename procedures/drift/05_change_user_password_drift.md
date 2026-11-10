# D05 - change_user_password.yml

## Cel testu
Potwierdzenie, ze po recznej zmianie hasla ponowne wykonanie playbooka z ta sama wartoscia wejsciowa przywraca oczekiwany hash.

## Zakres
- Host / zakres testowy: `edge`
- Playbook remediacyjny: `playbooks/change_user_password.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/change_user_password.yml --limit edge
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "getent shadow ansible | cut -d: -f2 | sha256sum > /tmp/ansible-password-baseline.sha256"
ansible edge -i inventories/hosts.yml -b -m shell -a "printf 'ansible:DriftTest123!\n' | chpasswd"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "echo baseline:; cat /tmp/ansible-password-baseline.sha256; echo drift:; getent shadow ansible | cut -d: -f2 | sha256sum"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/change_user_password.yml --limit edge
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "echo baseline:; cat /tmp/ansible-password-baseline.sha256; echo after:; getent shadow ansible | cut -d: -f2 | sha256sum; rm -f /tmp/ansible-password-baseline.sha256"
```

## Kryteria zaliczenia
- digest po recznej zmianie rozni sie od bazowego,
- po remediacji digest ponownie odpowiada wartosci bazowej.

## Uwagi
W pierwszym i drugim uruchomieniu playbooka podaj **to samo testowe haslo**. Nie umieszczaj hasla na screenshotach.
