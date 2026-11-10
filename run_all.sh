#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"

export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"

cd "${ROOT_DIR}"4


run_playbook() {
    local playbook="$1"
    shift

    echo
    echo "============================================================"
    echo " URUCHAMIAM: ${playbook}"
    echo "============================================================"
    echo

    ansible-playbook "${PLAYBOOK_DIR}/${playbook}" "$@"
}

echo
echo "============================================================"
echo " SPRAWDZENIE KONFIGURACJI ANSIBLE"
echo "============================================================"
echo

echo "ANSIBLE_CONFIG=${ANSIBLE_CONFIG}"

if [[ ! -f "${ANSIBLE_CONFIG}" ]]; then
    echo "ERROR: Nie znaleziono ansible.cfg:"
    echo "${ANSIBLE_CONFIG}"
    exit 1
fi

echo
echo "Sprawdzanie inventory..."
echo

ansible-inventory --graph

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


# ============================================================
# ETAP 1: BASELINE I INICJALIZACJA
# ============================================================

# Wylaczenie automatycznych aktualizacji
run_playbook "disable_unattended_updates.yml"

# Konfiguracja sieci
run_playbook "change_netplan.yml"

# Instalacja i inicjalizacja Etckeeper
run_playbook "install_etckeeper.yml"

# Dodanie bannera bezpieczenstwa
run_playbook "add_security_banner.yml"

# Zmiana nazwy uzytkownika lub grupy
run_playbook "change_user_name_or_group.yml"

# Utworzenie uzytkownika dla blue_group
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__"
    }'

# Utworzenie uzytkownika dla red_group
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_RED__"
    }'

# Usuniecie starego uzytkownika z blue_group
run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'

# Usuniecie starego uzytkownika z red_group
run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_RED__",
        "force_delete_user_sudoers_files": true
    }'

# Zmiana hasla uzytkownika
run_playbook "change_user_password.yml"


# ============================================================
# ETAP 2: HARDENING I INFRASTRUKTURA
# ============================================================

# Instalacja Docker
run_playbook "install_docker.yml"

# Instalacja Nginx
run_playbook "install_nginx.yml"

# Instalacja AppArmor
run_playbook "install_apparmor.yml"

# Restart systemu
run_playbook "reboot_system.yml"

# Hardening Docker
run_playbook "harden_docker.yml"

# Hardening SSH
run_playbook "harden_ssh.yml" \
    --extra-vars '{"ssh_target": "all"}'

# Instalacja i konfiguracja Fail2Ban
run_playbook "install_fail2ban.yml"

# Konfiguracja firewalla
run_playbook "configure_firewall.yml"

# Aktualizacja i usuwanie podatnosci
run_playbook "patch_vulnerabilities.yml"

# Hardening Nginx
run_playbook "harden_nginx.yml"


# ============================================================
# ETAP 3: DEPLOYMENT APLIKACJI
# ============================================================

# Wdrozenie aplikacji
run_playbook "deploy_application.yml"


# ============================================================
# ETAP 4: WERYFIKACJA, MONITORING I UTRZYMANIE
# ============================================================

# Audyt systemu Lynis
run_playbook "install_lynis_or_audit.yml"

# Enumeracja sieci za pomoca Nmap
run_playbook "install_nmap_or_enumerate.yml"

# Testy uwierzytelniania za pomoca Hydra
run_playbook "install_hydra_or_attack.yml"

# Skanowanie serwera WWW za pomoca Nikto
run_playbook "install_nikto_or_scan.yml"

# Instalacja agenta Zabbix
run_playbook "install_zabbix_agent.yml"

# Instalacja Zabbix Get i test agenta
echo "Weryfikacja sudo na management przed instalacja zabbix-get"
sudo -v
run_playbook "install_zabbix_get_or_test_zabbix_agent.yml" -K

# Egzekwowanie baseline uprawnien plikow
run_playbook "enforce_file_baseline.yml"

# Egzekwowanie baseline konfiguracji sudo
run_playbook "enforce_sudo_baseline.yml"

# Egzekwowanie baseline wersji pakietow
run_playbook "enforce_version_baseline.yml"

# Rotacja hasel
run_playbook "rotate_passwords.yml"


echo
echo "============================================================"
echo " WSZYSTKIE PLAYBOOKI ZOSTALY WYKONANE POMYSLNIE"
echo "============================================================"