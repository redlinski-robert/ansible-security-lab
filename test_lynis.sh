#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"
RESULT_DIR="${ROOT_DIR}/reports"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RESULT_FILE="${RESULT_DIR}/test_lynis_${RUN_ID}.csv"
export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"
cd "${ROOT_DIR}"

mkdir -p "${RESULT_DIR}"
printf 'playbook,status,exit_code,elapsed_seconds\n' > "${RESULT_FILE}"

FAILED_RUNS=0

run_playbook() {
    local playbook="$1"
    shift
    local start_time end_time elapsed exit_code status

    if [[ ! -f "${PLAYBOOK_DIR}/${playbook}" ]]; then
        echo "ERROR: Nie znaleziono playbooka ${PLAYBOOK_DIR}/${playbook}"
        printf '"%s",MISSING,127,0\n' "${playbook}" >> "${RESULT_FILE}"
        FAILED_RUNS=$((FAILED_RUNS + 1))
        sleep 10
        return 0
    fi

    echo
    echo "============================================================"
    echo " URUCHAMIAM: ${playbook}"
    echo " Wyniki zbiorcze: ${RESULT_FILE}"
    echo "============================================================"

    start_time="$(date +%s)"
    if ansible-playbook "${PLAYBOOK_DIR}/${playbook}" "$@"; then
        exit_code=0
        status=PASS
    else
        exit_code=$?
        status=FAIL
        FAILED_RUNS=$((FAILED_RUNS + 1))
    fi
    end_time="$(date +%s)"
    elapsed=$((end_time - start_time))

    printf '"%s",%s,%s,%s\n' "${playbook}" "${status}" "${exit_code}" "${elapsed}" >> "${RESULT_FILE}"
    echo "WYNIK: ${status} (kod ${exit_code}, ${elapsed}s)"
    echo "Pauza 10 sekund..."
    sleep 10
}

# ============================================================
# SPRAWDZENIE KONFIGURACJI ANSIBLE
# ============================================================

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
ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

echo
echo "============================================================"
echo " WLACZENIE NTP"
echo "============================================================"
echo
ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl set-ntp true && if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then systemctl restart systemd-timesyncd; fi"

echo
echo "============================================================"
echo " STATUS CZASU PO SYNCHRONIZACJI"
echo "============================================================"
echo
ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

# ============================================================
# TYMCZASOWY / AWARYJNY USER
# ============================================================

echo
echo "============================================================"
echo " TWORZENIE GRUPY my-test-group"
echo "============================================================"
echo
ansible all -b -m group -a "name=my-test-group state=present"

echo
echo "============================================================"
echo " TWORZENIE USERA my-test-user"
echo "============================================================"
echo
ansible all -b -m user \
    -a "name=my-test-user group=my-test-group shell=/bin/bash create_home=yes"

echo
echo "============================================================"
echo " KONFIGURACJA SUDO DLA my-test-user"
echo "============================================================"
echo
ansible all -b -m shell \
    -a "printf '%s\\n' 'my-test-user ALL=(ALL:ALL) ALL' > /etc/sudoers.d/my-test-user-user && chmod 0440 /etc/sudoers.d/my-test-user-user && visudo -cf /etc/sudoers"

# Lynis instalowany jako pierwszy, a nastepnie uruchamiany ponownie
# w kolejnosci listy, aby wykonac audyt po zmianach systemu.
run_playbook "install_lynis_or_audit.yml"

run_playbook "change_netplan.yml"
run_playbook "install_etckeeper.yml"
run_playbook "add_security_banner.yml"
run_playbook "change_user_password.yml"
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

run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'

run_playbook "install_docker.yml"
run_playbook "install_nginx.yml"
run_playbook "install_apparmor.yml"
run_playbook "reboot_system.yml"
run_playbook "install_lynis_or_audit.yml"
run_playbook "harden_docker.yml"
run_playbook "install_nmap_or_enumerate.yml"
run_playbook "install_hydra_or_attack.yml"
run_playbook "harden_ssh.yml" \
    --extra-vars '{"ssh_target":"all"}'
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
run_playbook "rotate_passwords.yml" \
    --extra-vars '{"hide_sensitive_logs":true}'

echo
echo "============================================================"
echo " TEST LYNIS ZAKONCZONY"
echo " Wyniki: ${RESULT_FILE}"
echo " Liczba nieudanych uruchomien: ${FAILED_RUNS}"
echo "============================================================"

if (( FAILED_RUNS > 0 )); then
    exit 1
fi
