#!/usr/bin/env bash

set -euo pipefail
# Test funkcjonalny zaawansowany - sprawdza poprawnosc konfiguracji i dzialania systemu po zastosowaniu playbookow

# ============================================================
# KONFIGURACJA PROJEKTU
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"

# Parametry srodowiska testowego. Dostosuj je tutaj dla innego inventory.
TEMP_TEST_USER="my-test-user"
TEMP_TEST_GROUP="my-test-group"
MIGRATED_TEST_USER="my-new-user"
MIGRATED_TEST_GROUP="my-new-group"
ANSIBLE_TEST_USER="ansible"
ANSIBLE_TEST_GROUP="ansible"
PASSWORD_TEST_USER="ansible"
BLUE_OLD_USER="__UZUPELNIJ_UZYTKOWNIK_BLUE__"
RED_OLD_USER="__UZUPELNIJ_UZYTKOWNIK_RED__"

NGINX_TEST_EDGE_IP="__UZUPELNIJ_IP_EDGE__"
FIREWALL_SOURCE_HOST="scanner"
FIREWALL_DESTINATION_IP="__UZUPELNIJ_IP_EDGE__"
FIREWALL_TEST_PORT="443"
FIREWALL_TEST_URL="https://__UZUPELNIJ_IP_EDGE__"
DEPLOY_TEST_EDGE_IP="__UZUPELNIJ_IP_EDGE__"
DEPLOY_TEST_CONTAINERS=(app_backend app_frontend app_db)
ZABBIX_TEST_AGENT_IP="__UZUPELNIJ_IP_APP__"
ZABBIX_TEST_AGENT_PORT="10050"
FILE_BASELINE_TEST_PATH="/etc/etckeeper/etckeeper.conf"
FILE_BASELINE_TEST_TARGET="all"
VERSION_BASELINE_TEST_PACKAGE="ca-certificates"

export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"

cd "${ROOT_DIR}"


# ============================================================
# FUNKCJA URUCHAMIAJACA PLAYBOOK
# ============================================================

CHECK_FAILURES=0
USER_CHECK_TARGET=""
DELETE_USER_CHECK=""

run_check() {
    local description="$1"
    local target="$2"
    local module="$3"
    local arguments="$4"

    echo
    echo "------------------------------------------------------------"
    echo " TEST: ${description} (${target})"
    echo "------------------------------------------------------------"

    if ansible "${target}" -b -m "${module}" -a "${arguments}"; then
        echo "PASS: ${description}"
    else
        echo "FAIL: ${description}"
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi

    echo "10 sekund na zrzut ekranu..."
    sleep 10
}

run_local_check() {
    local description="$1"
    shift

    echo
    echo "------------------------------------------------------------"
    echo " TEST LOKALNY: ${description}"
    echo "------------------------------------------------------------"

    if "$@"; then
        echo "PASS: ${description}"
    else
        echo "FAIL: ${description}"
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi

    echo "10 sekund na zrzut ekranu..."
    sleep 10
}

run_procedure_checks() {
    local playbook="$1"
    local check_target="${2:-}"

    echo
    echo "============================================================"
    echo " TESTY PROCEDURY: ${playbook}"
    echo "============================================================"

    case "${playbook}" in
        disable_unattended_updates.yml)
            run_check "Usluga unattended-upgrades jest wylaczona" all shell "state=\$(systemctl is-active unattended-upgrades.service 2>/dev/null || true); test \"\$state\" = inactive || test \"\$state\" = unknown"
            run_check "Autostart unattended-upgrades jest wylaczony" all shell "state=\$(systemctl is-enabled unattended-upgrades.service 2>/dev/null || true); test \"\$state\" = disabled || test \"\$state\" = masked || test \"\$state\" = not-found"
            run_check "Konfiguracja APT Periodic" all shell "apt-config dump | grep -E 'APT::Periodic::(Enable|Update-Package-Lists|Unattended-Upgrade)'"
            run_check "Timery APT sa nieaktywne" all shell 'for unit in apt-daily.timer apt-daily-upgrade.timer; do state=$(systemctl is-active "$unit" 2>/dev/null || true); printf "%s: %s\\n" "$unit" "$state"; case "$state" in inactive|unknown|not-found) ;; *) exit 1;; esac; done'
            ;;
        change_netplan.yml)
            run_check "Generowanie konfiguracji Netplan" all command "netplan generate"
            run_check "Rozwiazywanie nazw DNS" all command "getent ahosts security.ubuntu.com"
            ;;
        install_etckeeper.yml)
            run_check "Pakiet etckeeper" all command "dpkg-query -W etckeeper"
            run_check "Repozytorium Git dla /etc" all command "etckeeper vcs rev-parse HEAD"
            run_check "Ostatnie commity etckeeper" all command "git -C /etc log --oneline -n 3"
            ;;
        add_security_banner.yml)
            run_check "Poprawnosc konfiguracji SSH" blue_group command "sshd -t"
            run_check "Aktywne ustawienia banneru SSH" blue_group shell "sshd -T | grep -E '^(banner|usepam)'"
            run_check "Uprawnienia plikow bannerow" blue_group shell "stat -c '%U:%G %a %n' /etc/issue.net /etc/motd"
            ;;
        change_user_name_or_group.yml)
            run_check "Nowa nazwa uzytkownika" all command "getent passwd ${MIGRATED_TEST_USER}"
            run_check "Stary uzytkownik usuniety po migracji" all shell "! getent passwd ${TEMP_TEST_USER}"
            run_check "Nowa grupa istnieje" all command "getent group ${MIGRATED_TEST_GROUP}"
            run_check "Uzytkownik ma nowa grupe podstawowa" all shell "test \"\$(id -gn ${MIGRATED_TEST_USER})\" = ${MIGRATED_TEST_GROUP}"
            run_check "Katalog domowy przeniesiony" all command "test -d /home/${MIGRATED_TEST_USER}"
            ;;
        create_user.yml)
            if [[ "${check_target}" != blue_group && "${check_target}" != red_group ]]; then
                echo "FAIL: Nieznany target create_user.yml: ${check_target:-brak}"
                CHECK_FAILURES=$((CHECK_FAILURES + 1))
                return 0
            fi
            run_check "Wpis uzytkownika ${ANSIBLE_TEST_USER}" "${check_target}" command "getent passwd ${ANSIBLE_TEST_USER}"
            run_check "UID i grupa podstawowa ${ANSIBLE_TEST_USER}" "${check_target}" shell "id ${ANSIBLE_TEST_USER} && test \"\$(id -gn ${ANSIBLE_TEST_USER})\" = ${ANSIBLE_TEST_GROUP}"
            run_check "Katalog domowy i .ssh ${ANSIBLE_TEST_USER}" "${check_target}" shell "stat -c '%U:%G %a %n' /home/${ANSIBLE_TEST_USER} /home/${ANSIBLE_TEST_USER}/.ssh"
            run_check "Skladnia sudoers" "${check_target}" command "visudo -cf /etc/sudoers"
            run_check "Uprawnienia sudo ${ANSIBLE_TEST_USER}" "${check_target}" command "sudo -l -U ${ANSIBLE_TEST_USER}"
            ;;
        delete_old_user.yml)
            if [[ -z "${DELETE_USER_CHECK}" ]]; then
                echo "FAIL: Brak DELETE_USER_CHECK dla delete_old_user.yml."
                CHECK_FAILURES=$((CHECK_FAILURES + 1))
                return 0
            fi
            run_check "Usuniecie wpisu passwd ${DELETE_USER_CHECK}" "${check_target}" shell "! getent passwd ${DELETE_USER_CHECK}"
            run_check "Usuniecie wpisu shadow ${DELETE_USER_CHECK}" "${check_target}" shell "! getent shadow ${DELETE_USER_CHECK}"
            run_check "Usuniecie katalogu domowego ${DELETE_USER_CHECK}" "${check_target}" shell "test ! -d /home/${DELETE_USER_CHECK}"
            run_check "Brak procesow ${DELETE_USER_CHECK}" "${check_target}" shell "! pgrep -u ${DELETE_USER_CHECK}"
            run_check "Usuniecie sudoers ${DELETE_USER_CHECK}" "${check_target}" shell "test ! -e /etc/sudoers.d/${DELETE_USER_CHECK}-user"
            ;;
        change_user_password.yml|rotate_passwords.yml)
            local procedure_file
            if [[ "${playbook}" == change_user_password.yml ]]; then
                procedure_file="08_change_user_password.md"
            else
                procedure_file="29_rotate_passwords.md"
            fi
            run_check "Status hasla bez ujawniania skrotu" all command "passwd -S ${PASSWORD_TEST_USER}"
            echo "Logowanie nowym haslem oraz weryfikacje Vault wykonaj recznie wedlug procedures/functional/${procedure_file}; skrypt nie odczytuje ani nie wyswietla sekretow."
            ;;
        change_ansible_user_password.yml)
            run_check "Status hasla konta Ansible" all command "passwd -S ansible"
            echo "Probe logowania nowym i starym haslem wykonaj recznie wedlug procedures/functional/change-ansible-user-password.md."
            ;;
        install_docker.yml)
            run_check "Autostart uslugi Docker" app command "systemctl is-enabled docker"
            run_check "Aktywnosc uslugi Docker" app command "systemctl is-active docker"
            run_check "Wersja Docker CLI" app command "docker version"
            run_check "Wersja Docker Compose" app command "docker compose version"
            run_check "Biblioteka Docker dla Pythona" app command "python3 -c 'import docker; print(docker.__version__)'"
            run_check "Test uruchomienia kontenera Docker" app command "docker run --rm hello-world"
            ;;
        install_nginx.yml|harden_nginx.yml)
            run_check "Pakiety Nginx i OpenSSL" edge_servers command "dpkg-query -W nginx openssl"
            run_check "Skladnia konfiguracji Nginx" edge_servers command "nginx -t"
            run_check "Autostart uslugi Nginx" edge_servers command "systemctl is-enabled nginx"
            run_check "Aktywnosc uslugi Nginx" edge_servers command "systemctl is-active nginx"
            run_check "Uprawnienia katalogu TLS Nginx" edge_servers command "stat -c '%U:%G %a %n' /etc/nginx/ssl"
            run_check "Uprawnienia katalogu logow Nginx" edge_servers command "stat -c '%U:%G %a %n' /var/log/nginx"
            if [[ "${playbook}" == harden_nginx.yml ]]; then
                run_local_check "Odpowiedz HTTPS edge" curl -kI "https://${NGINX_TEST_EDGE_IP}"
                run_local_check "Negocjacja TLS 1.2" bash -c 'openssl s_client -connect "$1:443" -tls1_2 -brief </dev/null' _ "${NGINX_TEST_EDGE_IP}"
                echo "Negatywne testy TLS 1.0/1.1 i kontrole naglowkow opisz zgodnie z procedures/functional/23_harden_nginx.md."
            fi
            ;;
        install_apparmor.yml)
            run_check "Pakiety AppArmor" blue_group command "dpkg-query -W apparmor apparmor-utils"
            run_check "Aktywnosc uslugi AppArmor" blue_group command "systemctl is-active apparmor"
            run_check "Status AppArmor" blue_group command "aa-enabled"
            ;;
        reboot_system.yml)
            run_check "Dostepnosc hostow po restarcie" all ping ""
            run_check "Uslugi zakonczone bledem" all command "systemctl --failed"
            ;;
        install_lynis_or_audit.yml)
            run_check "Pakiet Lynis" blue_group shell "dpkg-query -W lynis || lynis --version"
            ;;
        harden_docker.yml)
            run_check "Poprawnosc JSON konfiguracji Dockera" app_servers command "python3 -m json.tool /etc/docker/daemon.json"
            run_check "Aktywnosc Docker" app_servers command "systemctl is-active docker"
            run_check "Aktywnosc auditd" app_servers command "systemctl is-active auditd"
            run_check "Reguly auditd" app_servers command "auditctl -l"
            run_check "Pozytywny test uruchomienia kontenera" app_servers shell "docker run --rm alpine echo ok"
            echo "Testy blokowania niebezpiecznych opcji i restartu demona pominiete automatycznie; uruchamiaj je kontrolowanie zgodnie z procedura harden-docker."
            ;;
        install_nmap_or_enumerate.yml)
            run_check "Pakiet Nmap" scanner_servers shell "dpkg-query -W nmap || nmap --version"
            run_check "Test skanowania localhost" scanner_servers command "nmap -p 22,80,443 localhost"
            ;;
        install_hydra_or_attack.yml)
            run_check "Pakiet Hydra" scanner_servers shell "dpkg-query -W hydra || hydra --version"
            ;;
        harden_ssh.yml)
            run_check "Skladnia konfiguracji SSH" all command "sshd -t"
            run_check "Efektywne ustawienia SSH" all shell "sshd -T | grep -E '^(port|maxauthtries|allowtcpforwarding|x11forwarding|loglevel)'"
            run_check "Polaczenie Ansible po zmianach SSH" all ping ""
            ;;
        install_fail2ban.yml)
            run_check "Pakiet fail2ban" blue_group command "dpkg-query -W fail2ban"
            run_check "Autostart fail2ban" blue_group command "systemctl is-enabled fail2ban"
            run_check "Aktywnosc fail2ban" blue_group command "systemctl is-active fail2ban"
            run_check "Status fail2ban" blue_group command "fail2ban-client status"
            run_check "Status jail SSH" blue_group command "fail2ban-client status sshd"
            ;;
        configure_firewall.yml)
            run_check "Stan UFW" blue_group command "ufw status verbose"
            run_check "Kolejnosc regul UFW" blue_group command "ufw status numbered"
            run_check "Reguly Docker-USER" app_servers command "iptables -S DOCKER-USER"
            run_check "Aktywne porty i nasluch" blue_group command "ss -lntup"
            run_check "Polaczenie firewall ${FIREWALL_SOURCE_HOST} -> ${FIREWALL_DESTINATION_IP}:${FIREWALL_TEST_PORT}" "${FIREWALL_SOURCE_HOST}" shell "nc -vz -w 3 ${FIREWALL_DESTINATION_IP} ${FIREWALL_TEST_PORT}"
            run_check "Odpowiedz HTTP/S przez firewall" "${FIREWALL_SOURCE_HOST}" shell "curl -k --connect-timeout 5 ${FIREWALL_TEST_URL}"
            ;;
        patch_vulnerabilities.yml)
            run_check "Wersje zaktualizowanych pakietow" blue_group shell "dpkg -l | grep -E 'vim|policykit-1'"
            run_check "Pakiety zablokowane przez APT" blue_group command "apt-mark showhold"
            ;;
        deploy_application.yml)
            run_check "Stan uslug Compose" app_servers shell "docker compose -f /var/opt/fullstack-app/docker-compose.yml ps"
            run_check "Healthcheck backendu" app_servers shell "curl -fsS http://127.0.0.1:5000/api/health"
            run_check "Profile AppArmor aplikacji" app_servers shell "aa-status | grep -E 'apparmor-(db|backend|frontend)'"
            run_local_check "Frontend przez reverse proxy" curl -fkI "https://${DEPLOY_TEST_EDGE_IP}"
            local container_name
            for container_name in "${DEPLOY_TEST_CONTAINERS[@]}"; do
                run_check "Profil AppArmor kontenera ${container_name}" app_servers shell "docker inspect --format '{% raw %}{{.AppArmorProfile}}{% endraw %}' ${container_name}"
            done
            ;;
        install_nikto_or_scan.yml)
            run_check "Wersja pakietu Nikto" scanner_servers command "dpkg-query -W nikto"
            run_check "Pakiety Nikto zablokowane przed aktualizacja" scanner_servers shell "apt-mark showhold | grep nikto"
            ;;
        install_zabbix_agent.yml)
            run_check "Pakiet Zabbix Agent 2" blue_group command "dpkg-query -W zabbix-agent2"
            run_check "Autostart agenta Zabbix" blue_group command "systemctl is-enabled zabbix-agent2"
            run_check "Aktywnosc agenta Zabbix" blue_group command "systemctl is-active zabbix-agent2"
            run_check "Port nasluchu agenta Zabbix" blue_group shell "ss -lntup | grep zabbix"
            run_check "Ostatnie logi agenta Zabbix" blue_group command "tail -n 30 /var/log/zabbix/zabbix_agent2.log"
            ;;
        install_zabbix_get_or_test_zabbix_agent.yml)
            run_local_check "Wersja zabbix_get" zabbix_get --version
            run_local_check "Odpowiedz agenta Zabbix" zabbix_get -s "${ZABBIX_TEST_AGENT_IP}" -p "${ZABBIX_TEST_AGENT_PORT}" -k agent.ping
            run_local_check "Czas pracy agenta Zabbix" zabbix_get -s "${ZABBIX_TEST_AGENT_IP}" -p "${ZABBIX_TEST_AGENT_PORT}" -k system.uptime
            run_local_check "Nazwa hosta agenta Zabbix" zabbix_get -s "${ZABBIX_TEST_AGENT_IP}" -p "${ZABBIX_TEST_AGENT_PORT}" -k system.hostname
            run_local_check "Dostepna pamiec agenta Zabbix" zabbix_get -s "${ZABBIX_TEST_AGENT_IP}" -p "${ZABBIX_TEST_AGENT_PORT}" -k 'vm.memory.size[available]'
            run_local_check "Wolne miejsce na / agenta Zabbix" zabbix_get -s "${ZABBIX_TEST_AGENT_IP}" -p "${ZABBIX_TEST_AGENT_PORT}" -k 'vfs.fs.size[/,free]'
            ;;
        enforce_file_baseline.yml)
            run_check "Wlasciciel, uprawnienia i suma SHA256 pliku" "${FILE_BASELINE_TEST_TARGET}" shell "stat -c '%U:%G %a %n' ${FILE_BASELINE_TEST_PATH}; sha256sum ${FILE_BASELINE_TEST_PATH}"
            if [[ -f "${PLAYBOOK_DIR}/files/$(basename "${FILE_BASELINE_TEST_PATH}")" ]]; then
                run_local_check "Suma SHA256 pliku wzorcowego" sha256sum "${PLAYBOOK_DIR}/files/$(basename "${FILE_BASELINE_TEST_PATH}")"
            fi
            ;;
        enforce_sudo_baseline.yml)
            run_check "Skladnia sudoers" all command "visudo -cf /etc/sudoers"
            run_check "Pliki sudoers.d" all shell "find /etc/sudoers.d -maxdepth 1 -type f -printf '%m %u:%g %p\\n'"
            ;;
        enforce_version_baseline.yml)
            run_check "Dostepna wersja pakietu ${VERSION_BASELINE_TEST_PACKAGE}" all command "apt-cache policy ${VERSION_BASELINE_TEST_PACKAGE}"
            run_check "Zainstalowana wersja pakietu ${VERSION_BASELINE_TEST_PACKAGE}" all shell "dpkg-query -W -f='\${Package} \${Version}\\n' ${VERSION_BASELINE_TEST_PACKAGE}"
            ;;
        *)
            echo "Brak automatycznych testow dla ${playbook}; sprawdz odpowiednia procedure w procedures/functional/."
            ;;
    esac
}

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

    run_procedure_checks "${playbook}" "${USER_CHECK_TARGET}"
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
USER_CHECK_TARGET="blue_group"
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__"
    }'
USER_CHECK_TARGET=""


# ============================================================
# 06B. CREATE USER - RED GROUP
# ============================================================

# Ten przebieg ma osobny user_target i osobne old_ansible_user.
USER_CHECK_TARGET="red_group"
run_playbook "create_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "username": "ansible",
        "groupname": "ansible",
        "sudo_access_method": "sudoers_user",
        "change_ansible_user": true,
        "old_ansible_user": "__UZUPELNIJ_UZYTKOWNIK_RED__"
    }'
USER_CHECK_TARGET=""


# ============================================================
# 07A. DELETE OLD USER - BLUE GROUP
# ============================================================

USER_CHECK_TARGET="blue_group"
DELETE_USER_CHECK="${BLUE_OLD_USER}"
run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "blue_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_BLUE__",
        "force_delete_user_sudoers_files": true
    }'
USER_CHECK_TARGET=""
DELETE_USER_CHECK=""


# ============================================================
# 07B. DELETE OLD USER - RED GROUP
# ============================================================

USER_CHECK_TARGET="red_group"
DELETE_USER_CHECK="${RED_OLD_USER}"
run_playbook "delete_old_user.yml" \
    --extra-vars '{
        "user_target": "red_group",
        "old_user": "__UZUPELNIJ_UZYTKOWNIK_RED__",
        "force_delete_user_sudoers_files": true
    }'
USER_CHECK_TARGET=""
DELETE_USER_CHECK=""


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


echo
echo "============================================================"
if (( CHECK_FAILURES > 0 )); then
    echo " TESTY FUNKCJONALNE ZAKONCZONE BLEDAMI: ${CHECK_FAILURES}"
    echo "============================================================"
    exit 1
fi

echo " WSZYSTKIE TESTY FUNKCJONALNE ZAKONCZONE"
echo "============================================================"
