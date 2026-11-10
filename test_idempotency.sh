#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"
export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"

cd "${ROOT_DIR}"

run_playbook_twice() {
    local playbook="$1"
    shift

    echo
    echo "============================================================"
    echo " IDEMPOTENCJA: PIERWSZY RUN - ${playbook}"
    echo "============================================================"
    ansible-playbook "${PLAYBOOK_DIR}/${playbook}" "$@"

    echo
    echo "########## ${playbook} - PIERWSZY RUN ZAKONCZONY ##########"
    echo "Drugi run tego samego playbooka za 20 sekund..."
    sleep 20

    echo
    echo "============================================================"
    echo " IDEMPOTENCJA: DRUGI RUN - ${playbook}"
    echo "============================================================"
    ansible-playbook "${PLAYBOOK_DIR}/${playbook}" "$@"

    echo
    echo "########## ${playbook} - DRUGI RUN ZAKONCZONY ##########"
    sleep 20
}

run_command() {
    local description="$1"
    shift

    echo
    echo "============================================================"
    echo " IDEMPOTENCJA: Uruchomienie komendy - ${description}"
    echo "============================================================"
    "$@"
}

echo
echo "============================================================"
echo " TEST IDEMPOTENCJI - PLAYBOOK PO PLAYBOOKU"
echo "============================================================"

run_command "Sprawdzenie konfiguracji Ansible" ansible-inventory --graph

run_command "Sprawdzenie czasu i NTP" \
    ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

run_command "Wlaczenie NTP" \
    ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl set-ntp true && if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then systemctl restart systemd-timesyncd; fi"

run_command "Status czasu po synchronizacji" \
    ansible all -i inventories/hosts.yml -b -m shell \
    -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

run_command "Utworzenie grupy my-test-group" \
    ansible all -b -m group -a "name=my-test-group state=present"

run_command "Utworzenie uzytkownika my-test-user" \
    ansible all -b -m user \
    -a "name=my-test-user group=my-test-group shell=/bin/bash create_home=yes"

run_command "Konfiguracja sudo dla my-test-user" \
    ansible all -b -m shell \
    -a "printf '%s\\n' 'my-test-user ALL=(ALL:ALL) ALL' > /etc/sudoers.d/my-test-user-user && chmod 0440 /etc/sudoers.d/my-test-user-user && visudo -cf /etc/sudoers"

run_playbook_twice "disable_unattended_updates.yml"
run_playbook_twice "change_netplan.yml"
run_playbook_twice "install_etckeeper.yml"
run_playbook_twice "add_security_banner.yml"
run_playbook_twice "change_user_name_or_group.yml"

run_playbook_twice "create_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__"
    }'

run_playbook_twice "create_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_RED__"
    }'

run_playbook_twice "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'

run_playbook_twice "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_RED__",
        "force_delete_user_sudoers_files": true
    }'

run_playbook_twice "change_user_password.yml"
run_playbook_twice "install_docker.yml"
run_playbook_twice "install_nginx.yml"
run_playbook_twice "install_apparmor.yml"
run_playbook_twice "reboot_system.yml"
run_playbook_twice "install_lynis_or_audit.yml"
run_playbook_twice "harden_docker.yml"
run_playbook_twice "install_nmap_or_enumerate.yml"
run_playbook_twice "install_hydra_or_attack.yml"
run_playbook_twice "harden_ssh.yml" \
    --extra-vars '{"ssh_target": "all"}'
run_playbook_twice "install_fail2ban.yml"
run_playbook_twice "configure_firewall.yml"
run_playbook_twice "patch_vulnerabilities.yml"
run_playbook_twice "deploy_application.yml"
run_playbook_twice "install_nikto_or_scan.yml"
run_playbook_twice "harden_nginx.yml"
run_playbook_twice "install_zabbix_agent.yml"
run_command "Weryfikacja sudo na management przed instalacja zabbix-get" sudo -v
run_playbook_twice "install_zabbix_get_or_test_zabbix_agent.yml" -K
run_playbook_twice "enforce_file_baseline.yml"
run_playbook_twice "enforce_sudo_baseline.yml"
run_playbook_twice "enforce_version_baseline.yml"
run_playbook_twice "rotate_passwords.yml"

echo
echo "============================================================"
echo " TEST IDEMPOTENCJI ZAKONCZONY"
echo "============================================================"
