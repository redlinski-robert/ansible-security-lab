# D12 - reboot_system.yml

## Ocena przydatnosci testu dryftu
`reboot_system.yml` nie utrzymuje trwalego desired state. Jego dzialaniem jest jednorazowy restart, dlatego klasyczny scenariusz **reczna zmiana → remediacja konfiguracji** nie ma tu poprawnej semantyki.

> Wszystkie komendy wykonuj w srodowisku laboratoryjnym, z katalogu glownego projektu `ansible-lab`. Wprowadzaj tylko **jeden dryft naraz** i ogranicz test do jednego hosta przez `--limit`, jesli playbook na to pozwala.

## Zalecany test zamiast dryftu
```bash
ansible edge -i inventories/hosts.yml -b -m shell -a "uptime -s"
ansible-playbook -i inventories/hosts.yml playbooks/reboot_system.yml --limit edge
ansible edge -i inventories/hosts.yml -m ping
ansible edge -i inventories/hosts.yml -b -m shell -a "uptime -s; systemctl is-system-running || true"
```

## Kryterium
W macierzy dryftu oznacz jako **N/D - brak trwalego stanu konfiguracyjnego do remediacji**. Dowod pozostaje w testach funkcjonalnych / persistence po restarcie.
