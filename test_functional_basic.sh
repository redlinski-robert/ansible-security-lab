#!/usr/bin/env bash

set -euo pipefail
# Test funkcjonalny podstawowy - sprawdza, czy wszystkie playbooki zostaly zainstalowane (nie sprawdza ich dzialania)

# ============================================================
# KONFIGURACJA PROJEKTU
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"

export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"

cd "${ROOT_DIR}"


# ============================================================
# FUNKCJA URUCHAMIAJACA PLAYBOOK
# ============================================================

run_playbook() {
    local playbook="$1"
    shift

    if [[ ! -f "${PLAYBOOK_DIR}/${playbook}" ]]; then
        echo
        echo "ERROR: Nie znaleziono playbooka:"
        echo "${PLAYBOOK_DIR}/${playbook}"
        exit 1
    fi

    echo
    echo "============================================================"
    echo " URUCHAMIAM: ${playbook}"
    echo "============================================================"
    echo

    ansible-playbook \
        "${PLAYBOOK_DIR}/${playbook}" \
        "$@"
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
# 01. DISABLE UNATTENDED UPDATES
# ============================================================

run_playbook "disable_unattended_updates.yml"


# ============================================================
# 02. CHANGE NETPLAN
# ============================================================

run_playbook "change_netplan.yml"


# ============================================================
# 03. INSTALL ETCKEEPER
# ============================================================

run_playbook "install_etckeeper.yml"


# ============================================================
# 04. SECURITY BANNER
# ============================================================

run_playbook "add_security_banner.yml"


# ============================================================
# 05. CHANGE USER NAME / GROUP
# ============================================================

run_playbook "change_user_name_or_group.yml"


# ============================================================
# 06A. CREATE USER - BLUE GROUP
# ============================================================

# user_target wybiera grupa, ktorej group_vars zostana zaktualizowane.
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__"
    }'


# ============================================================
# 06B. CREATE USER - RED GROUP
# ============================================================

# Ten przebieg ma osobny user_target i osobne old_ansible_user.
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_RED__"
    }'


# ============================================================
# 07A. DELETE OLD USER - BLUE GROUP
# ============================================================

run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'


# ============================================================
# 07B. DELETE OLD USER - RED GROUP
# ============================================================

run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_RED__",
        "force_delete_user_sudoers_files": true
    }'


# ============================================================
# 08. CHANGE USER PASSWORD
# ============================================================

run_playbook "change_user_password.yml"


# ============================================================
# 09. INSTALL DOCKER
# ============================================================

run_playbook "install_docker.yml"


# ============================================================
# 10. INSTALL NGINX
# ============================================================

run_playbook "install_nginx.yml"


# ============================================================
# 11. INSTALL APPARMOR
# ============================================================

run_playbook "install_apparmor.yml"


# ============================================================
# 12. REBOOT SYSTEM
# ============================================================

run_playbook "reboot_system.yml"


# ============================================================
# 13. INSTALL LYNIS / AUDIT
# ============================================================

run_playbook "install_lynis_or_audit.yml"


# ============================================================
# 14. HARDEN DOCKER
# ============================================================

run_playbook "harden_docker.yml"


# ============================================================
# 15. INSTALL NMAP / ENUMERATE
# ============================================================

run_playbook "install_nmap_or_enumerate.yml"


# ============================================================
# 16. INSTALL HYDRA / ATTACK
# ============================================================

run_playbook "install_hydra_or_attack.yml"


# ============================================================
# 17. HARDEN SSH
# ============================================================

run_playbook "harden_ssh.yml" \
    --extra-vars '{"ssh_target": "all"}'


# ============================================================
# 18. INSTALL FAIL2BAN
# ============================================================

run_playbook "install_fail2ban.yml"


# ============================================================
# 19. CONFIGURE FIREWALL
# ============================================================

run_playbook "configure_firewall.yml"


# ============================================================
# 20. PATCH VULNERABILITIES
# ============================================================

run_playbook "patch_vulnerabilities.yml"


# ============================================================
# 21. DEPLOY APPLICATION
# ============================================================

run_playbook "deploy_application.yml"


# ============================================================
# 22. INSTALL NIKTO / SCAN
# ============================================================

run_playbook "install_nikto_or_scan.yml"


# ============================================================
# 23. HARDEN NGINX
# ============================================================

run_playbook "harden_nginx.yml"


# ============================================================
# 24. INSTALL ZABBIX AGENT
# ============================================================

run_playbook "install_zabbix_agent.yml"


# ============================================================
# 25. INSTALL ZABBIX GET / TEST ZABBIX AGENT
#
# Ten playbook wymaga -K
# ============================================================

echo "Weryfikacja sudo na management przed instalacja zabbix-get"
sudo -v
run_playbook "install_zabbix_get_or_test_zabbix_agent.yml" -K


# ============================================================
# 26. ENFORCE FILE BASELINE
# ============================================================

run_playbook "enforce_file_baseline.yml"


# ============================================================
# 27. ENFORCE SUDO BASELINE
# ============================================================

run_playbook "enforce_sudo_baseline.yml"


# ============================================================
# 28. ENFORCE VERSION BASELINE
# ============================================================

run_playbook "enforce_version_baseline.yml"


# ============================================================
# 29. ROTATE PASSWORDS
# ============================================================

run_playbook "rotate_passwords.yml"


# ============================================================
# KONIEC
# ============================================================

echo
echo "============================================================"
echo " WSZYSTKIE PLAYBOOKI ZOSTALY WYKONANE POMYSLNIE"
echo "============================================================"
echo