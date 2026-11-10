# D21 - deploy_application.yml

## Cel testu
Potwierdzenie, ze reczna zmiana pliku backendu jest nadpisywana zawartoscia repozytorium, a aplikacja po przebudowie dziala.

## Zakres
- Host / zakres testowy: `app`
- Playbook remediacyjny: `playbooks/deploy_application.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/deploy_application.yml --limit app
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "echo '# DRIFT_TEST' >> /var/opt/fullstack-app/backend/app.py"
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "tail -n 3 /var/opt/fullstack-app/backend/app.py; grep -n DRIFT_TEST /var/opt/fullstack-app/backend/app.py"
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/deploy_application.yml --limit app
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible app -i inventories/hosts.yml -b -m shell -a "grep -n DRIFT_TEST /var/opt/fullstack-app/backend/app.py || echo DRIFT_USUNIETY; cd /var/opt/fullstack-app && docker compose ps; curl -fsS http://127.0.0.1:5000/api/health"
```

## Kryteria zaliczenia
- przed remediacja plik zawiera `DRIFT_TEST`;
- po playbooku znacznik znika;
- kontenery dzialaja i health endpoint zwraca stan zdrowy.
