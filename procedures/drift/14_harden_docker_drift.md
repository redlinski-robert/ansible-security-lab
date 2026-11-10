# D14 - harden_docker.yml

## Cel testu
Potwierdzenie, ze reczne oslabienie `icc` w `daemon.json` jest przywracane przez hardening.

## Zakres
- Host / zakres testowy: `app`
- Playbook remediacyjny: `playbooks/harden_docker.yml`

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `__UZUPELNIJ_NAZWA_PROJEKTU__`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Procedura testowa

### 1. Ustal stan poprawny
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_docker.yml --limit app
```

### 2. Wprowadz kontrolowany dryft
```bash
ansible app -i inventories/hosts.yml -b -m shell -a 'python3 -c "import json; p=\"/etc/docker/daemon.json\"; d=json.load(open(p)); d[\"icc\"]=True; open(p,\"w\").write(json.dumps(d,indent=2)+\"\\n\")"' 
```

### 3. Potwierdz wystapienie dryftu
```bash
ansible app -i inventories/hosts.yml -b -m shell -a 'python3 -c "import json; print(json.load(open(\"/etc/docker/daemon.json\")).get(\"icc\"))"' 
```
Stan niezgodny musi byc widoczny **przed** ponownym uruchomieniem playbooka.

### 4. Uruchom remediacje
```bash
ansible-playbook -i inventories/hosts.yml playbooks/harden_docker.yml --limit app
```
W logu Ansible zadanie odpowiedzialne za naprawe powinno przejsc jako `changed`.

### 5. Zweryfikuj stan po remediacji
```bash
ansible app -i inventories/hosts.yml -b -m shell -a 'python3 -c "import json; d=json.load(open(\"/etc/docker/daemon.json\")); print(\"icc=\",d.get(\"icc\")); print(\"no-new-privileges=\",d.get(\"no-new-privileges\")); print(\"live-restore=\",d.get(\"live-restore\"))"; systemctl is-active docker' 
```

## Kryteria zaliczenia
- przed remediacja `icc=True`,
- po remediacji `icc=False`,
- Docker pozostaje aktywny.

## Uwagi
Wprowadzany dryft pozostawia poprawny JSON. Blad skladni JSON bylby testem obslugi bledow, nie dryftu konfiguracji.
