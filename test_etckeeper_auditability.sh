#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# ETCKEEPER AUDITABILITY TEST
# ============================================================
# Najpierw zatrzymujemy jednostki aktualizacji bez zmiany plikow w /etc.
# Potem uruchamiamy etckeeper, disable_unattended_updates i reszte playbookow.
# Na koncu tylko wyswietlamy historie i statystyki commitow, bez tworzenia masek.
# Zapis zmian w etckeeper pozostaje zadaniem istniejacych playbookow.

# BASH_SOURCE[0] wskazuje plik tego skryptu. dirname wybiera jego katalog,
# a cd i pwd zwracaja pelna sciezke, niezaleznie od miejsca uruchomienia.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Jesli skrypt umieszczono w procedures/, katalog projektu jest poziom wyzej.
if [[ ! -f "${ROOT_DIR}/ansible.cfg" && -f "${ROOT_DIR}/../ansible.cfg" ]]; then
    ROOT_DIR="$(cd "${ROOT_DIR}/.." && pwd)"
fi
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"
INVENTORY="${ROOT_DIR}/inventories/hosts.yml"
export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"
cd "$ROOT_DIR"

[[ -f "$ANSIBLE_CONFIG" && -f "$INVENTORY" ]] || {
    echo "Brak ansible.cfg lub inventories/hosts.yml w katalogu projektu"
    exit 1
}

ansible-inventory -i "$INVENTORY" --graph

# $1 to nazwa playbooka. shift ja usuwa, a "$@" przekazuje pozostale argumenty,
# np. --extra-vars lub -K, bez zmiany ich wartosci.
run_playbook() {
    local playbook="$1"
    shift
    [[ -f "${PLAYBOOK_DIR}/${playbook}" ]] || {
        echo "Brak playbooka: ${playbook}"
        exit 1
    }
    echo
    echo "URUCHAMIAM: ${playbook}"
    ansible-playbook -i "$INVENTORY" "${PLAYBOOK_DIR}/${playbook}" "$@"
}

echo
echo "Inventory zostalo poprawnie wczytane."


# ============================================================
# SYNCHRONIZACJA CZASU
# ============================================================

echo
echo "============================================================"
echo " SPRAWDZENIE CZASU / NTP"
echo "============================================================"
echo

ansible all \
    -i inventories/hosts.yml \
    -b \
    -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

echo
echo "============================================================"
echo " WLACZENIE NTP"
echo "============================================================"
echo

ansible all \
    -i inventories/hosts.yml \
    -b \
    -m shell \
    -a "timedatectl set-ntp true && if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then systemctl restart systemd-timesyncd; fi"

echo
echo "============================================================"
echo " STATUS CZASU PO SYNCHRONIZACJI"
echo "============================================================"
echo

ansible all \
    -i inventories/hosts.yml \
    -b \
    -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"


# ============================================================
# TYMCZASOWY / AWARYJNY USER
# ============================================================

echo
echo "============================================================"
echo " TWORZENIE GRUPY my-test-group"
echo "============================================================"
echo

ansible all \
    -b \
    -m group \
    -a "name=my-test-group state=present"


echo
echo "============================================================"
echo " TWORZENIE USERA my-test-user"
echo "============================================================"
echo

ansible all \
    -b \
    -m user \
    -a "name=my-test-user group=my-test-group shell=/bin/bash create_home=yes"


echo
echo "============================================================"
echo " KONFIGURACJA SUDO DLA my-test-user"
echo "============================================================"
echo

ansible all \
    -b \
    -m shell \
    -a "printf '%s\n' 'my-test-user ALL=(ALL:ALL) ALL' > /etc/sudoers.d/my-test-user-user && chmod 0440 /etc/sudoers.d/my-test-user-user && visudo -cf /etc/sudoers"


# Zatrzymujemy najpierw timery, potem uslugi. stop zmienia stan dzialania,
# ale nie zapisuje konfiguracji w /etc. Jednostki nieobecne na hoscie pomijamy.
# Trwale wylaczenie wykona pozniej oryginalny disable_unattended_updates.yml.
# Polecenie po -a jest w jednej linii, bez poczatkowego znaku nowej linii.
# Wieloliniowy argument sprawial problem parserowi polecen ad hoc Ansible.
ansible all -i "$INVENTORY" -b -m ansible.builtin.shell -a 'set -e; for unit in apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service unattended-upgrades.service; do if [ "$(systemctl show "$unit" --property=LoadState --value)" != "not-found" ]; then systemctl stop "$unit"; fi; done'

run_playbook "install_etckeeper.yml"

run_playbook "disable_unattended_updates.yml"

run_playbook "change_netplan.yml"

run_playbook "add_security_banner.yml"

run_playbook "change_user_name_or_group.yml"

run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__"
    }'

run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_RED__"
    }'

run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'

run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_RED__",
        "force_delete_user_sudoers_files": true
    }'

run_playbook "change_user_password.yml"

run_playbook "install_docker.yml"

run_playbook "install_nginx.yml"

run_playbook "install_apparmor.yml"

run_playbook "reboot_system.yml"

run_playbook "install_lynis_or_audit.yml"

run_playbook "harden_docker.yml"

run_playbook "install_nmap_or_enumerate.yml"

run_playbook "install_hydra_or_attack.yml"

run_playbook "harden_ssh.yml" \
    --extra-vars '{"ssh_target": "all"}'

run_playbook "install_fail2ban.yml"

run_playbook "configure_firewall.yml"

run_playbook "patch_vulnerabilities.yml"

run_playbook "deploy_application.yml"

run_playbook "install_nikto_or_scan.yml"

run_playbook "harden_nginx.yml"

run_playbook "install_zabbix_agent.yml"

echo "Weryfikacja sudo na management przed instalacja zabbix-get"
sudo -v
run_playbook "install_zabbix_get_or_test_zabbix_agent.yml" -K

run_playbook "enforce_file_baseline.yml"

run_playbook "enforce_sudo_baseline.yml"

run_playbook "enforce_version_baseline.yml"

run_playbook "rotate_passwords.yml"

echo
echo "WSZYSTKIE PLAYBOOKI ZOSTALY WYKONANE POMYSLNIE"

# Wybrany commit mozna pozniej obejrzec recznie, podstawiajac jego hash:
# ansible scanner -i inventories/hosts.yml -b -m command -a "git -C /etc show --stat --oneline HASH_COMMITA"
# Lub na wszystkich hostach, o ile wskazany hash istnieje w ich repozytoriach:
# ansible all -i inventories/hosts.yml -b -m command -a "git -C /etc show --stat --oneline HASH_COMMITA"
# Commity poszczegolnych hostow maja wlasne hashe. HEAD wskazuje ostatni commit
# kazdego hosta i moze zastapic HASH_COMMITA przy sprawdzaniu ostatniego zapisu.

# ============================================================
# RAPORT ETCKEEPER
# ============================================================

REPORT_DIR="${ROOT_DIR}/reports/etckeeper_auditability/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

echo
echo "============================================================"
echo " ETCKEEPER - RAPORT HISTORII"
echo "============================================================"
echo
echo "Katalog raportu:"
echo "$REPORT_DIR"
echo

# ------------------------------------------------------------
# Pelna historia techniczna
# ------------------------------------------------------------
# Szczegolowy raport trafia do pliku, aby nie generowac duzego
# szumu informacyjnego w terminalu.
#
# Zawiera:
# - hash commita,
# - opis commita,
# - liste zmienionych plikow,
# - statystyki zmian.

ansible all \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "git -C /etc log --all --stat --oneline" \
    > "${REPORT_DIR}/commits_full.log"

# ------------------------------------------------------------
# Lista wszystkich commitow
# ------------------------------------------------------------

ansible all \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "git -C /etc log --all --oneline" \
    > "${REPORT_DIR}/commits_list.log"

# ------------------------------------------------------------
# Klasyfikacja commitow
# ------------------------------------------------------------
# W terminalu pokazujemy tylko:
#
# [ZAPELNIONY] HASH OPIS
# [PUSTY]      HASH OPIS
#
# Pelne podsumowanie jest jednoczesnie zapisywane do pliku.

echo
echo "============================================================"
echo " KLASYFIKACJA COMMITOW ETCKEEPER"
echo "============================================================"
echo

ansible all \
    -i "$INVENTORY" \
    -b \
    -m shell \
    -a "git -C /etc log --all --pretty=format:'%H|%s' | while IFS='|' read -r commit message; do
        if git -C /etc diff-tree --quiet --no-commit-id --root -r \"\$commit\"; then
            echo \"[PUSTY]      \$commit \$message\"
        else
            echo \"[ZAPELNIONY] \$commit \$message\"
        fi
    done" \
    | tee "${REPORT_DIR}/commits_summary.log"

# ------------------------------------------------------------
# Niezatwierdzone zmiany
# ------------------------------------------------------------

ansible all \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "git -C /etc status --porcelain" \
    > "${REPORT_DIR}/working_tree_status.log"

echo
echo "============================================================"
echo " RAPORT ETCKEEPER ZAPISANY"
echo "============================================================"
echo
echo "Podsumowanie:"
echo "  ${REPORT_DIR}/commits_summary.log"
echo
echo "Lista commitow:"
echo "  ${REPORT_DIR}/commits_list.log"
echo
echo "Pelna historia ze statystykami:"
echo "  ${REPORT_DIR}/commits_full.log"
echo
echo "Stan niezapisanych zmian:"
echo "  ${REPORT_DIR}/working_tree_status.log"