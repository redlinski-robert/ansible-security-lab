#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# TESTY DRYFTU KONFIGURACJI ANSIBLE
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Gdy skrypt zostanie skopiowany do katalogu __UZUPELNIJ_NAZWA_PROJEKTU__, ROOT_DIR jest poprawny.
# Przy uruchomieniu z innej lokalizacji mozna podac jawnie:
#   ANSIBLE_LAB_ROOT=/home/__UZUPELNIJ_UZYTKOWNIK_KONTROLERA__/__UZUPELNIJ_NAZWA_PROJEKTU__ ./test_drift.sh
if [[ -n "${ANSIBLE_LAB_ROOT:-}" ]]; then
    ROOT_DIR="$(cd "${ANSIBLE_LAB_ROOT}" && pwd)"
fi

PLAYBOOK_DIR="${ROOT_DIR}/playbooks"
INVENTORY="${ROOT_DIR}/inventories/hosts.yml"
PROCEDURE_DIR="${ROOT_DIR}/procedures/drift"
SCREENSHOT_DELAY="${SCREENSHOT_DELAY:-10}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT_DIR}/reports/drift/${RUN_ID}"
MASTER_LOG="${REPORT_DIR}/drift_full.log"
SUMMARY_FILE="${REPORT_DIR}/summary.txt"

export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"

mkdir -p "${REPORT_DIR}"
cd "${ROOT_DIR}"

# Wszystkie komunikaty trafiaja rownoczesnie do terminala i logu zbiorczego.
exec > >(tee -a "${MASTER_LOG}") 2>&1

CURRENT_TEST_ID=""
CURRENT_TEST_NAME=""
CURRENT_TEST_LOG=""
CURRENT_FAILED=0
LAST_RC=0
TOTAL_FAILURES=0
PASSWORD_VARS_FILE=""

RESULT_IDS=()
RESULT_NAMES=()
RESULT_STATUS=()
SELECTED_TESTS=("$@")

cleanup() {
    if [[ -n "${PASSWORD_VARS_FILE}" && -f "${PASSWORD_VARS_FILE}" ]]; then
        rm -f "${PASSWORD_VARS_FILE}"
    fi
}
trap cleanup EXIT

# ============================================================
# FUNKCJE POMOCNICZE
# ============================================================

line() {
    printf '%s\n' "============================================================"
}

start_test() {
    CURRENT_TEST_ID="$1"
    CURRENT_TEST_NAME="$2"
    CURRENT_TEST_LOG="${REPORT_DIR}/${CURRENT_TEST_ID}_${CURRENT_TEST_NAME}.log"
    CURRENT_FAILED=0

    echo
    line
    echo " ${CURRENT_TEST_ID}: ${CURRENT_TEST_NAME}"
    echo " Log: ${CURRENT_TEST_LOG}"
    line
    echo
}

stage() {
    local label="$1"
    shift

    local -a cmd=("$@")
    local i shell_module=0

    # Dla ansible.builtin.shell wymuszamy przerwanie przy pierwszym bledzie
    # w sekwencji polecen. Bez tego np. nieudany `test` w srodku linii
    # moglby zostac zamaskowany przez poprawne ostatnie polecenie.
    if [[ "${cmd[0]:-}" == "ansible" ]]; then
        for ((i = 0; i < ${#cmd[@]}; i++)); do
            if [[ "${cmd[$i]}" == "-m" && "${cmd[$((i + 1))]:-}" == "shell" ]]; then
                shell_module=1
            fi
            if (( shell_module == 1 )) && [[ "${cmd[$i]}" == "-a" && -n "${cmd[$((i + 1))]:-}" ]]; then
                cmd[$((i + 1))]="set -e; ${cmd[$((i + 1))]}"
                break
            fi
        done
    elif [[ "${cmd[0]:-}" == "bash" && "${cmd[1]:-}" == "-c" && -n "${cmd[2]:-}" ]]; then
        cmd[2]="set -e; ${cmd[2]}"
    fi

    echo
    echo "------------------------------------------------------------"
    echo " ${label}"
    echo "------------------------------------------------------------"
    printf 'CMD: '
    printf '%q ' "${cmd[@]}"
    echo

    "${cmd[@]}" 2>&1 | tee -a "${CURRENT_TEST_LOG}"
    LAST_RC=${PIPESTATUS[0]}

    if (( LAST_RC == 0 )); then
        echo "OK: ${label}"
    else
        echo "FAIL (${LAST_RC}): ${label}"
        CURRENT_FAILED=1
    fi

    return 0
}

run_shell() {
    local label="$1"
    local script
    script="$(cat)"
    stage "${label}" bash -c "${script}"
}

pause_for_screenshot() {
    local suggested_name="$1"
    echo
    echo "Dowod do raportu: ${suggested_name}"
    if [[ "${SCREENSHOT_DELAY}" =~ ^[0-9]+$ ]] && (( SCREENSHOT_DELAY > 0 )); then
        echo "${SCREENSHOT_DELAY} sekund na zrzut ekranu..."
        sleep "${SCREENSHOT_DELAY}"
    fi
}

finish_test() {
    local forced_status="${1:-}"
    local status

    if [[ -n "${forced_status}" ]]; then
        status="${forced_status}"
    elif (( CURRENT_FAILED == 0 )); then
        status="PASS"
    else
        status="FAIL"
    fi

    RESULT_IDS+=("${CURRENT_TEST_ID}")
    RESULT_NAMES+=("${CURRENT_TEST_NAME}")
    RESULT_STATUS+=("${status}")

    case "${status}" in
        FAIL|BLOCKED)
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
            ;;
    esac

    echo
    echo "WYNIK ${CURRENT_TEST_ID}: ${status}"
}

block_if_baseline_failed() {
    if (( LAST_RC != 0 )); then
        echo "Nie wprowadzam dryftu, poniewaz nie udalo sie ustalic poprawnego stanu bazowego."
        finish_test "BLOCKED"
        return 0
    fi
    return 1
}

should_run() {
    local id="$1"
    local requested normalized

    if (( ${#SELECTED_TESTS[@]} == 0 )); then
        return 0
    fi

    for requested in "${SELECTED_TESTS[@]}"; do
        normalized="${requested^^}"
        normalized="${normalized#D}"
        if [[ "${normalized}" =~ ^[0-9]+$ ]]; then
            printf -v normalized '%02d' "$((10#${normalized}))"
        fi
        if [[ "D${normalized}" == "${id}" ]]; then
            return 0
        fi
    done

    return 1
}

prepare_password_vars() {
    if [[ -n "${PASSWORD_VARS_FILE}" && -f "${PASSWORD_VARS_FILE}" ]]; then
        return 0
    fi

    local secret="${DRIFT_TEST_PASSWORD:-}"
    if [[ -z "${secret}" ]]; then
        echo
        echo "D05 wymaga tej samej wartosci hasla w przebiegu bazowym i remediacji."
        read -r -s -p "Podaj testowe haslo dla konta ansible (min. 8 znakow): " secret
        echo
    fi

    if (( ${#secret} < 8 )); then
        echo "ERROR: Haslo testowe musi miec co najmniej 8 znakow."
        return 1
    fi

    PASSWORD_VARS_FILE="$(mktemp "${REPORT_DIR}/.d05_password.XXXXXX.json")"
    chmod 0600 "${PASSWORD_VARS_FILE}"

    DRIFT_SECRET_VALUE="${secret}" python3 - "${PASSWORD_VARS_FILE}" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump({"secret_manage_password": os.environ["DRIFT_SECRET_VALUE"]}, fh)
PY

    unset secret DRIFT_TEST_PASSWORD DRIFT_SECRET_VALUE 2>/dev/null || true
    export PASSWORD_VARS_FILE
}

# ============================================================
# WERYFIKACJA SRODOWISKA
# ============================================================

line
echo " TESTY DRYFTU - START"
echo " ROOT_DIR=${ROOT_DIR}"
echo " ANSIBLE_CONFIG=${ANSIBLE_CONFIG}"
echo " REPORT_DIR=${REPORT_DIR}"
line

for required_file in "${ANSIBLE_CONFIG}" "${INVENTORY}"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "ERROR: Nie znaleziono wymaganego pliku: ${required_file}"
        exit 1
    fi
done

for required_cmd in ansible ansible-playbook python3; do
    if ! command -v "${required_cmd}" >/dev/null 2>&1; then
        echo "ERROR: Brak wymaganej komendy: ${required_cmd}"
        exit 1
    fi
done

echo
echo "Sprawdzanie inventory..."
ansible-inventory -i "${INVENTORY}" --graph
if (( $? != 0 )); then
    echo "ERROR: Inventory nie zostalo poprawnie wczytane."
    exit 1
fi

echo
echo "Sprawdzenie lacznosci z hostami..."
ansible all -i "${INVENTORY}" -m ping
if (( $? != 0 )); then
    echo "ERROR: Co najmniej jeden host jest nieosiagalny. Nie rozpoczynam testow dryftu."
    exit 1
fi

# ============================================================
# SYNCHRONIZACJA CZASU / NTP - jak w test_functional_2.sh
# ============================================================

echo
line
echo " SPRAWDZENIE CZASU / NTP"
line
ansible all -i "${INVENTORY}" -b -m shell -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

echo
line
echo " WLACZENIE NTP"
line
ansible all -i "${INVENTORY}" -b -m shell -a "timedatectl set-ntp true && if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then systemctl restart systemd-timesyncd; fi"

echo
line
echo " STATUS CZASU PO SYNCHRONIZACJI"
line
ansible all -i "${INVENTORY}" -b -m shell -a "timedatectl status | grep -E 'Time zone|System clock synchronized|NTP service'"

# ============================================================
# D01 - disable_unattended_updates.yml
# ============================================================

test_d01() {
    start_test "D01" "disable_unattended_updates"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/disable_unattended_updates.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i 's/APT::Periodic::Unattended-Upgrade \"0\";/APT::Periodic::Unattended-Upgrade \"1\";/' /etc/apt/apt.conf.d/20auto-upgrades"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -E 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade)' /etc/apt/apt.conf.d/20auto-upgrades; grep -q 'APT::Periodic::Unattended-Upgrade \"1\";' /etc/apt/apt.conf.d/20auto-upgrades"
    pause_for_screenshot "D01_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/disable_unattended_updates.yml"
    pause_for_screenshot "D01_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -E 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade)' /etc/apt/apt.conf.d/20auto-upgrades; grep -q 'APT::Periodic::Unattended-Upgrade \"0\";' /etc/apt/apt.conf.d/20auto-upgrades; state=\$(systemctl is-active unattended-upgrades.service 2>/dev/null || true); echo service=\$state; test \"\$state\" = inactive -o \"\$state\" = unknown -o \"\$state\" = not-found"
    pause_for_screenshot "D01_C_po_remediacji"

    finish_test
}

# ============================================================
# D02 - change_netplan.yml
# ============================================================

test_d02() {
    start_test "D02" "change_netplan"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_netplan.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i 's/8\\.8\\.8\\.8/9.9.9.9/' /etc/netplan/99-ansible-dns.yaml; chmod 0644 /etc/netplan/99-ansible-dns.yaml"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -nE '8\\.8\\.8\\.8|9\\.9\\.9\\.9|1\\.1\\.1\\.1' /etc/netplan/99-ansible-dns.yaml; stat -c '%a %U %G %n' /etc/netplan/99-ansible-dns.yaml; grep -q '9.9.9.9' /etc/netplan/99-ansible-dns.yaml; test \"\$(stat -c '%a' /etc/netplan/99-ansible-dns.yaml)\" = 644"
    pause_for_screenshot "D02_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_netplan.yml"
    pause_for_screenshot "D02_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -nE '8\\.8\\.8\\.8|1\\.1\\.1\\.1' /etc/netplan/99-ansible-dns.yaml; stat -c '%a %U %G %n' /etc/netplan/99-ansible-dns.yaml; getent ahosts security.ubuntu.com | head; grep -q '8.8.8.8' /etc/netplan/99-ansible-dns.yaml; grep -q '1.1.1.1' /etc/netplan/99-ansible-dns.yaml; ! grep -q '9.9.9.9' /etc/netplan/99-ansible-dns.yaml; test \"\$(stat -c '%a' /etc/netplan/99-ansible-dns.yaml)\" = 600; getent ahosts security.ubuntu.com >/dev/null"
    pause_for_screenshot "D02_C_po_remediacji"

    finish_test
}

# ============================================================
# D03 - install_etckeeper.yml
# ============================================================

test_d03() {
    start_test "D03" "install_etckeeper"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_etckeeper.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "echo '# DRIFT_TEST' >> /etc/etckeeper/etckeeper.conf"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "tail -n 3 /etc/etckeeper/etckeeper.conf; grep -n DRIFT_TEST /etc/etckeeper/etckeeper.conf"
    pause_for_screenshot "D03_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_etckeeper.yml"
    pause_for_screenshot "D03_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n DRIFT_TEST /etc/etckeeper/etckeeper.conf || echo DRIFT_USUNIETY; git -C /etc config user.name; git -C /etc config user.email; git -C /etc log -1 --oneline; ! grep -q DRIFT_TEST /etc/etckeeper/etckeeper.conf"
    pause_for_screenshot "D03_C_po_remediacji"

    finish_test
}

# ============================================================
# D04 - add_security_banner.yml
# ============================================================

test_d04() {
    start_test "D04" "add_security_banner"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/add_security_banner.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "printf 'DRIFT_TEST\\n' > /etc/issue.net; chmod 0666 /etc/issue.net"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "cat /etc/issue.net; stat -c '%a %U %G' /etc/issue.net; grep -q '^DRIFT_TEST$' /etc/issue.net; test \"\$(stat -c '%a' /etc/issue.net)\" = 666"
    pause_for_screenshot "D04_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/add_security_banner.yml"
    pause_for_screenshot "D04_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n 'UWAGA! SYSTEM CHRONIONY' /etc/issue.net; stat -c '%a %U %G' /etc/issue.net; grep -E '^Banner|^UsePAM' /etc/ssh/sshd_config; test \"\$(stat -c '%a' /etc/issue.net)\" = 644; test \"\$(stat -c '%U:%G' /etc/issue.net)\" = root:root"
    pause_for_screenshot "D04_C_po_remediacji"

    finish_test
}

# ============================================================
# D05 - change_user_password.yml
# ============================================================

test_d05() {
    start_test "D05" "change_user_password"

    if ! prepare_password_vars; then
        CURRENT_FAILED=1
        finish_test "BLOCKED"
        return
    fi

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_user_password.yml" -e "@${PASSWORD_VARS_FILE}"
    block_if_baseline_failed && return

    stage "2A. Zapisz bezpieczny odcisk hasha bazowego" ansible edge -i "${INVENTORY}" -b -m shell -a "getent shadow ansible | cut -d: -f2 | sha256sum > /tmp/ansible-password-baseline.sha256"
    stage "2B. Wprowadz kontrolowany dryft hasla" ansible edge -i "${INVENTORY}" -b -m shell -a "printf 'ansible:DriftTest123!\\n' | chpasswd"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "echo baseline:; cat /tmp/ansible-password-baseline.sha256; echo drift:; getent shadow ansible | cut -d: -f2 | sha256sum; baseline=\$(awk '{print \$1}' /tmp/ansible-password-baseline.sha256); drift=\$(getent shadow ansible | cut -d: -f2 | sha256sum | awk '{print \$1}'); test \"\$baseline\" != \"\$drift\""
    pause_for_screenshot "D05_A_dryft"

    stage "4. Uruchom remediacje tym samym desired password" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_user_password.yml" -e "@${PASSWORD_VARS_FILE}"
    pause_for_screenshot "D05_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "echo baseline:; cat /tmp/ansible-password-baseline.sha256; echo after:; getent shadow ansible | cut -d: -f2 | sha256sum; baseline=\$(awk '{print \$1}' /tmp/ansible-password-baseline.sha256); after=\$(getent shadow ansible | cut -d: -f2 | sha256sum | awk '{print \$1}'); test \"\$baseline\" = \"\$after\"; rm -f /tmp/ansible-password-baseline.sha256"
    pause_for_screenshot "D05_C_po_remediacji"

    finish_test
}

# ============================================================
# D06 - change_user_name_or_group.yml
# ============================================================

test_d06() {
    start_test "D06" "change_user_name_or_group"

    # Procedura zostaje zachowana, ale przygotowanie jest odporne na stan
    # pozostaly po testach funkcjonalnych: nie dopuszcza do istnienia naraz
    # my-test-user i my-new-user.
    stage "0. Przygotuj jednoznaczny stan wejsciowy" ansible edge -i "${INVENTORY}" -b -m shell -a "if id my-new-user >/dev/null 2>&1; then if id my-test-user >/dev/null 2>&1; then userdel -r my-test-user 2>/dev/null || userdel my-test-user; fi; getent group my-test-group >/dev/null && groupdel my-test-group 2>/dev/null || true; else getent group my-test-group >/dev/null || groupadd my-test-group; id my-test-user >/dev/null 2>&1 || useradd -m -g my-test-group -s /bin/bash my-test-user; fi"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_user_name_or_group.yml" --limit edge
    block_if_baseline_failed && return

    stage "1B. Potwierdz bazowy desired state" ansible edge -i "${INVENTORY}" -b -m shell -a "id my-new-user; getent group my-new-group; test -d /home/my-new-user; ! id my-test-user >/dev/null 2>&1"

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "usermod -l my-test-user -d /home/my-test-user -m my-new-user; groupmod -n my-test-group my-new-group"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "id my-test-user; getent group my-test-group; id my-new-user || true; getent group my-new-group || true; ! id my-new-user >/dev/null 2>&1"
    pause_for_screenshot "D06_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/change_user_name_or_group.yml" --limit edge
    pause_for_screenshot "D06_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "id my-new-user; getent group my-new-group; test -d /home/my-new-user && echo HOME_OK; ! id my-test-user >/dev/null 2>&1; ! getent group my-test-group >/dev/null 2>&1"
    pause_for_screenshot "D06_C_po_remediacji"

    finish_test
}

# ============================================================
# D07 - create_user.yml
# ============================================================

test_d07() {
    start_test "D07" "create_user"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/create_user.yml" --limit edge -e "username=drift-test-user groupname=drift-test-group sudo_access_method=none"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "usermod -s /bin/sh drift-test-user; chmod 0755 /home/drift-test-user/.ssh"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "getent passwd drift-test-user; stat -c '%a %U %G %n' /home/drift-test-user/.ssh; test \"\$(getent passwd drift-test-user | cut -d: -f7)\" = /bin/sh; test \"\$(stat -c '%a' /home/drift-test-user/.ssh)\" = 755"
    pause_for_screenshot "D07_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/create_user.yml" --limit edge -e "username=drift-test-user groupname=drift-test-group sudo_access_method=none"
    pause_for_screenshot "D07_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "getent passwd drift-test-user; stat -c '%a %U %G %n' /home/drift-test-user/.ssh; test \"\$(getent passwd drift-test-user | cut -d: -f7)\" = /bin/bash; test \"\$(stat -c '%a' /home/drift-test-user/.ssh)\" = 700"
    pause_for_screenshot "D07_C_po_remediacji"

    finish_test
}

# ============================================================
# D08 - delete_old_user.yml
# ============================================================

test_d08() {
    start_test "D08" "delete_old_user"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/delete_old_user.yml" --limit edge -e "old_user=drift-old-user"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "id drift-old-user >/dev/null 2>&1 || useradd -m -s /bin/bash drift-old-user; printf 'drift-old-user ALL=(ALL:ALL) ALL\\n' > /etc/sudoers.d/drift-old-user-user; chmod 0440 /etc/sudoers.d/drift-old-user-user"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "id drift-old-user; ls -l /etc/sudoers.d/drift-old-user-user; test -d /home/drift-old-user"
    pause_for_screenshot "D08_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/delete_old_user.yml" --limit edge -e "old_user=drift-old-user"
    pause_for_screenshot "D08_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "id drift-old-user || echo USER_ABSENT; test ! -e /etc/sudoers.d/drift-old-user-user && echo SUDOERS_ABSENT; test ! -d /home/drift-old-user && echo HOME_ABSENT; ! id drift-old-user >/dev/null 2>&1; test ! -e /etc/sudoers.d/drift-old-user-user; test ! -d /home/drift-old-user"
    pause_for_screenshot "D08_C_po_remediacji"

    finish_test
}

# ============================================================
# D09 - install_docker.yml
# ============================================================

test_d09() {
    start_test "D09" "install_docker"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_docker.yml" --limit app
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible app -i "${INVENTORY}" -b -m shell -a "systemctl disable --now docker"
    stage "3. Potwierdz dryft" ansible app -i "${INVENTORY}" -b -m shell -a "systemctl is-enabled docker || true; systemctl is-active docker || true; test \"\$(systemctl is-enabled docker 2>/dev/null || true)\" != enabled; test \"\$(systemctl is-active docker 2>/dev/null || true)\" != active"
    pause_for_screenshot "D09_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_docker.yml" --limit app
    pause_for_screenshot "D09_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible app -i "${INVENTORY}" -b -m shell -a "systemctl is-enabled docker; systemctl is-active docker; docker --version; docker compose version; test \"\$(systemctl is-enabled docker)\" = enabled; test \"\$(systemctl is-active docker)\" = active"
    pause_for_screenshot "D09_C_po_remediacji"

    finish_test
}

# ============================================================
# D10 - install_nginx.yml
# ============================================================

test_d10() {
    start_test "D10" "install_nginx"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nginx.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "echo '# DRIFT_TEST' >> /etc/nginx/sites-available/__UZUPELNIJ_DOMENA_APLIKACJI__.conf"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "tail -n 3 /etc/nginx/sites-available/__UZUPELNIJ_DOMENA_APLIKACJI__.conf; nginx -t; grep -q DRIFT_TEST /etc/nginx/sites-available/__UZUPELNIJ_DOMENA_APLIKACJI__.conf"
    pause_for_screenshot "D10_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nginx.yml" --limit edge
    pause_for_screenshot "D10_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n DRIFT_TEST /etc/nginx/sites-available/__UZUPELNIJ_DOMENA_APLIKACJI__.conf || echo DRIFT_USUNIETY; nginx -t; systemctl is-active nginx; ! grep -q DRIFT_TEST /etc/nginx/sites-available/__UZUPELNIJ_DOMENA_APLIKACJI__.conf"
    pause_for_screenshot "D10_C_po_remediacji"

    finish_test
}

# ============================================================
# D11 - install_apparmor.yml
# ============================================================

test_d11() {
    start_test "D11" "install_apparmor"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_apparmor.yml" --limit blue_group
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "systemctl disable --now apparmor"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "systemctl is-enabled apparmor || true; systemctl is-active apparmor || true; test \"\$(systemctl is-enabled apparmor 2>/dev/null || true)\" != enabled; test \"\$(systemctl is-active apparmor 2>/dev/null || true)\" != active"
    pause_for_screenshot "D11_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_apparmor.yml" --limit blue_group
    pause_for_screenshot "D11_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "systemctl is-enabled apparmor; systemctl is-active apparmor; aa-status | head -n 8; test \"\$(systemctl is-enabled apparmor)\" = enabled; test \"\$(systemctl is-active apparmor)\" = active"
    pause_for_screenshot "D11_C_po_remediacji"

    finish_test
}

# ============================================================
# D12 - reboot_system.yml (N/D dla klasycznego dryftu)
# ============================================================

test_d12() {
    start_test "D12" "reboot_system"

    echo "Ten playbook nie utrzymuje trwalego desired state."
    echo "Zgodnie z procedura wykonuje test restartu/persistence zamiast sztucznego dryftu."

    stage "Stan przed restartem" ansible blue_group -i "${INVENTORY}" -b -m shell -a "uptime -s"
    stage "Wykonaj reboot_system.yml" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/reboot_system.yml" --limit blue_group
    pause_for_screenshot "D12_B_reboot"
    stage "Lacznosc i stan po restarcie" ansible blue_group -i "${INVENTORY}" -m ping
    stage "Weryfikacja czasu startu i systemd" ansible blue_group -i "${INVENTORY}" -b -m shell -a "uptime -s; systemctl is-system-running || true"

    if (( CURRENT_FAILED == 0 )); then
        finish_test "N/D - test restartu PASS"
    else
        finish_test "FAIL"
    fi

    stage "Poczekaj na pelny powrot SSH po restarcie" \
        ansible blue_group \
        -i "${INVENTORY}" \
        -m wait_for_connection \
        -a "delay=15 timeout=600 sleep=5 connect_timeout=10"

}


# ============================================================
# D13 - install_lynis_or_audit.yml
# ============================================================

test_d13() {

    stage "0. Sprawdz gotowosc edge po restarcie" \
        ansible edge \
        -i "${INVENTORY}" \
        -m wait_for_connection \
        -a "timeout=300 sleep=5 connect_timeout=10"

    start_test "D13" "install_lynis_or_audit"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_lynis_or_audit.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "apt-mark unhold lynis || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y lynis"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' lynis 2>/dev/null || echo LYNIS_UNKNOWN; ! dpkg-query -W -f='\${Status}\n' lynis 2>/dev/null | grep -Eq '^[^ ]+ ok installed$'"
    pause_for_screenshot "D13_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_lynis_or_audit.yml" --limit edge
    pause_for_screenshot "D13_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\\n' lynis; dpkg --get-selections lynis; dpkg-query -W lynis >/dev/null; dpkg --get-selections lynis | grep -q '[[:space:]]hold$'"
    pause_for_screenshot "D13_C_po_remediacji"

    finish_test
}

# ============================================================
# D14 - harden_docker.yml
# ============================================================

test_d14() {
    start_test "D14" "harden_docker"

    stage "0. Sprawdz gotowosc app po restarcie" \
        ansible app \
        -i "${INVENTORY}" \
        -m wait_for_connection \
        -a "timeout=300 sleep=5 connect_timeout=10"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_docker.yml" --limit app
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible app -i "${INVENTORY}" -b -m shell -a 'python3 -c "import json; p=\"/etc/docker/daemon.json\"; d=json.load(open(p)); d[\"icc\"]=True; open(p,\"w\").write(json.dumps(d,indent=2)+\"\\n\")"'
    stage "3. Potwierdz dryft" ansible app -i "${INVENTORY}" -b -m shell -a 'python3 -c "import json; v=json.load(open(\"/etc/docker/daemon.json\")).get(\"icc\"); print(v); raise SystemExit(0 if v is True else 1)"'
    pause_for_screenshot "D14_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_docker.yml" --limit app
    pause_for_screenshot "D14_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible app -i "${INVENTORY}" -b -m shell -a 'python3 -c "import json; d=json.load(open(\"/etc/docker/daemon.json\")); print(\"icc=\",d.get(\"icc\")); print(\"no-new-privileges=\",d.get(\"no-new-privileges\")); print(\"live-restore=\",d.get(\"live-restore\")); raise SystemExit(0 if d.get(\"icc\") is False else 1)"; systemctl is-active docker'
    pause_for_screenshot "D14_C_po_remediacji"

    finish_test
}

# ============================================================
# D15 - install_nmap_or_enumerate.yml
# ============================================================

test_d15() {
    start_test "D15" "install_nmap_or_enumerate"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nmap_or_enumerate.yml" --limit scanner
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "apt-mark unhold nmap || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nmap"
    stage "3. Potwierdz dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "command -v nmap || echo NMAP_ABSENT; dpkg-query -W nmap || true; ! command -v nmap >/dev/null 2>&1"
    pause_for_screenshot "D15_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nmap_or_enumerate.yml" --limit scanner
    pause_for_screenshot "D15_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible scanner -i "${INVENTORY}" -b -m shell -a "nmap --version | head -n 1; dpkg --get-selections nmap; ls -ld /tmp/nmap_results; command -v nmap >/dev/null"
    pause_for_screenshot "D15_C_po_remediacji"

    finish_test
}

# ============================================================
# D16 - install_hydra_or_attack.yml
# ============================================================

test_d16() {
    start_test "D16" "install_hydra_or_attack"

    if [[ ! -f "${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass" ]]; then
        echo "BLOCKED: Brak inventories/.vault_passwords/generated_admin_secrets.pass."
        echo "Zgodnie z procedura najpierw wykonaj change_user_password.yml."
        finish_test "BLOCKED"
        return
    fi

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_hydra_or_attack.yml" --limit scanner
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "apt-mark unhold hydra || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y hydra"
    stage "3. Potwierdz dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "command -v hydra || echo HYDRA_ABSENT; dpkg-query -W hydra || true; ! command -v hydra >/dev/null 2>&1"
    pause_for_screenshot "D16_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_hydra_or_attack.yml" --limit scanner
    pause_for_screenshot "D16_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible scanner -i "${INVENTORY}" -b -m shell -a "hydra -h 2>&1 | head -n 2; dpkg --get-selections hydra; command -v hydra >/dev/null"
    pause_for_screenshot "D16_C_po_remediacji"

    finish_test
}

# ============================================================
# D17 - harden_ssh.yml
# ============================================================

test_d17() {
    start_test "D17" "harden_ssh"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_ssh.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i -E 's/^#?MaxAuthTries[[:space:]]+.*/MaxAuthTries 6/' /etc/ssh/sshd_config; sshd -t; systemctl reload ssh"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sshd -T | grep -E 'maxauthtries|allowtcpforwarding|x11forwarding|loglevel'; test \"\$(sshd -T | awk '/^maxauthtries /{print \$2; exit}')\" = 6"
    pause_for_screenshot "D17_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_ssh.yml"
    pause_for_screenshot "D17_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "sshd -T | grep -E 'maxauthtries|allowtcpforwarding|x11forwarding|loglevel'; sshd -t; test \"\$(sshd -T | awk '/^maxauthtries /{print \$2; exit}')\" = 3"
    pause_for_screenshot "D17_C_po_remediacji"

    finish_test
}

# ============================================================
# D18 - install_fail2ban.yml
# ============================================================

test_d18() {
    start_test "D18" "install_fail2ban"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_fail2ban.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i -E 's/^maxretry[[:space:]]*=.*/maxretry  = 99/' /etc/fail2ban/jail.local"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n '^maxretry' /etc/fail2ban/jail.local; grep -Eq '^maxretry[[:space:]]*=[[:space:]]*99$' /etc/fail2ban/jail.local"
    pause_for_screenshot "D18_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_fail2ban.yml" --limit edge
    pause_for_screenshot "D18_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n '^maxretry' /etc/fail2ban/jail.local; systemctl is-active fail2ban; fail2ban-client status sshd; grep -Eq '^maxretry[[:space:]]*=[[:space:]]*3$' /etc/fail2ban/jail.local"
    pause_for_screenshot "D18_C_po_remediacji"

    finish_test
}

# ============================================================
# D19 - configure_firewall.yml
# ============================================================

test_d19() {
    start_test "D19" "configure_firewall"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/configure_firewall.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "ufw logging off"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "ufw status verbose; ufw status verbose | grep -q 'Logging: off'"
    pause_for_screenshot "D19_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/configure_firewall.yml"
    pause_for_screenshot "D19_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "ufw status verbose; ufw status verbose | grep -Eq 'Logging: on'; ufw status verbose | grep -Eq 'Default: deny \(incoming\), allow \(outgoing\)'"
    pause_for_screenshot "D19_C_po_remediacji"

    finish_test
}

# ============================================================
# D20 - patch_vulnerabilities.yml
# ============================================================

test_d20() {
    start_test "D20" "patch_vulnerabilities"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/patch_vulnerabilities.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "apt-mark unhold vim || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y vim"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' vim 2>/dev/null || echo VIM_UNKNOWN; ! dpkg-query -W -f='\${Status}\n' vim 2>/dev/null | grep -Eq '^[^ ]+ ok installed$'"
    pause_for_screenshot "D20_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/patch_vulnerabilities.yml" --limit edge
    pause_for_screenshot "D20_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\\n' vim vim-common vim-runtime policykit-1; dpkg --get-selections vim; dpkg-query -W vim >/dev/null; dpkg --get-selections vim | grep -q '[[:space:]]hold$'"
    pause_for_screenshot "D20_C_po_remediacji"

    # apt-get remove vim usuwa rowniez metapakiet ubuntu-server. Po tescie przywracamy go,
    # aby kontrolowany dryft nie pozostawial skutkow ubocznych w dalszych testach.
    stage "6. Cleanup - przywroc metapakiet ubuntu-server" \
        ansible edge \
        -i "${INVENTORY}" \
        -b \
        -m apt \
        -a "name=ubuntu-server state=present update_cache=no"

    finish_test
}

# ============================================================
# D21 - deploy_application.yml
# ============================================================

test_d21() {
    start_test "D21" "deploy_application"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/deploy_application.yml" --limit app
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible app -i "${INVENTORY}" -b -m shell -a "echo '# DRIFT_TEST' >> /var/opt/fullstack-app/backend/app.py"
    stage "3. Potwierdz dryft" ansible app -i "${INVENTORY}" -b -m shell -a "tail -n 3 /var/opt/fullstack-app/backend/app.py; grep -n DRIFT_TEST /var/opt/fullstack-app/backend/app.py"
    pause_for_screenshot "D21_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/deploy_application.yml" --limit app
    pause_for_screenshot "D21_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible app -i "${INVENTORY}" -b -m shell -a "grep -n DRIFT_TEST /var/opt/fullstack-app/backend/app.py || echo DRIFT_USUNIETY; cd /var/opt/fullstack-app && docker compose ps; curl -fsS http://127.0.0.1:5000/api/health; ! grep -q DRIFT_TEST /var/opt/fullstack-app/backend/app.py"
    pause_for_screenshot "D21_C_po_remediacji"

    finish_test
}

# ============================================================
# D22 - install_nikto_or_scan.yml
# ============================================================

test_d22() {
    start_test "D22" "install_nikto_or_scan"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nikto_or_scan.yml" --limit scanner
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "apt-mark unhold nikto || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nikto"
    stage "3. Potwierdz dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "command -v nikto || echo NIKTO_ABSENT; dpkg-query -W nikto || true; ! command -v nikto >/dev/null 2>&1"
    pause_for_screenshot "D22_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_nikto_or_scan.yml" --limit scanner
    pause_for_screenshot "D22_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible scanner -i "${INVENTORY}" -b -m shell -a "nikto -Version 2>&1 | head; dpkg --get-selections nikto; command -v nikto >/dev/null"
    pause_for_screenshot "D22_C_po_remediacji"

    finish_test
}

# ============================================================
# D23 - harden_nginx.yml
# ============================================================

test_d23() {
    start_test "D23" "harden_nginx"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_nginx.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i -E 's/^SecRuleEngine[[:space:]]+.*/SecRuleEngine DetectionOnly/' /etc/nginx/modsecurity/modsecurity.conf"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n '^SecRuleEngine' /etc/nginx/modsecurity/modsecurity.conf; nginx -t; grep -Eq '^SecRuleEngine[[:space:]]+DetectionOnly$' /etc/nginx/modsecurity/modsecurity.conf"
    pause_for_screenshot "D23_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/harden_nginx.yml" --limit edge
    pause_for_screenshot "D23_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -n '^SecRuleEngine' /etc/nginx/modsecurity/modsecurity.conf; test -f /etc/nginx/conf.d/10-security-headers.conf && echo HEADERS_OK; nginx -t; systemctl is-active nginx; grep -Eq '^SecRuleEngine[[:space:]]+On$' /etc/nginx/modsecurity/modsecurity.conf"
    pause_for_screenshot "D23_C_po_remediacji"

    finish_test
}

# ============================================================
# D24 - install_zabbix_agent.yml
# ============================================================

test_d24() {
    start_test "D24" "install_zabbix_agent"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_zabbix_agent.yml"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "sed -i -E 's/^Server=.*/Server=127.0.0.1/' /etc/zabbix/zabbix_agent2.conf; systemctl stop zabbix-agent2"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -E '^(Hostname|Server|ServerActive)=' /etc/zabbix/zabbix_agent2.conf; systemctl is-active zabbix-agent2 || true; grep -q '^Server=127.0.0.1$' /etc/zabbix/zabbix_agent2.conf; test \"\$(systemctl is-active zabbix-agent2 2>/dev/null || true)\" != active"
    pause_for_screenshot "D24_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_zabbix_agent.yml"
    pause_for_screenshot "D24_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "grep -E '^(Hostname|Server|ServerActive)=' /etc/zabbix/zabbix_agent2.conf; systemctl is-enabled zabbix-agent2; systemctl is-active zabbix-agent2; zabbix_agent2 -t agent.ping; grep -q '^Server=__UZUPELNIJ_IP_KONTROLERA__$' /etc/zabbix/zabbix_agent2.conf; grep -q '^ServerActive=$' /etc/zabbix/zabbix_agent2.conf"
    pause_for_screenshot "D24_C_po_remediacji"

    finish_test
}

# ============================================================
# D25 - install_zabbix_get_or_test_zabbix_agent.yml
# ============================================================

test_d25() {
    start_test "D25" "install_zabbix_get_or_test_zabbix_agent"
    stage "0. Odswiez timestamp sudo" sudo -v

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/install_zabbix_get_or_test_zabbix_agent.yml" --limit edge,localhost -K
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft na kontrolerze" sudo apt-get remove -y zabbix-get
    stage "3. Potwierdz dryft" bash -c "command -v zabbix_get || echo ZABBIX_GET_ABSENT; ! command -v zabbix_get >/dev/null 2>&1"
    pause_for_screenshot "D25_A_dryft"

    stage "4. Uruchom remediacje i test Zabbix" \
    ansible-playbook \
    -i "${INVENTORY}" \
    "${PLAYBOOK_DIR}/install_zabbix_get_or_test_zabbix_agent.yml" \
    --limit edge,localhost \
    -e zabbix_state=present \
    -e zabbix_run_test=true

    pause_for_screenshot "D25_B_ansible"

    stage "5. Zweryfikuj zabbix_get na kontrolerze" \
        bash -c 'zabbix_get --version && test "$(zabbix_get -s __UZUPELNIJ_IP_EDGE__ -p 10050 -k agent.ping)" = "1"'

    stage "5.1. Zweryfikuj stan present na agencie" \
        ansible edge \
        -i "${INVENTORY}" \
        -b \
        -m shell \
        -a "grep '^Server=' /etc/zabbix/zabbix_agent2.conf && test -e /etc/zabbix/ansible-backup/zabbix-agent2.server.original"
    stage "6. Przywroc konfiguracje agenta po tescie" \
        ansible-playbook \
        -i "${INVENTORY}" \
        "${PLAYBOOK_DIR}/install_zabbix_get_or_test_zabbix_agent.yml" \
        --limit edge,localhost \
        -e zabbix_state=absent \
        -e zabbix_run_test=false


    pause_for_screenshot "D25_C_po_remediacji"

    stage "7. Zweryfikuj rollback" \
        ansible edge \
        -i "${INVENTORY}" \
        -b \
        -m shell \
        -a "grep '^Server=' /etc/zabbix/zabbix_agent2.conf && test ! -e /etc/zabbix/ansible-backup/zabbix-agent2.server.original"

    finish_test
}

# ============================================================
# D26 - enforce_file_baseline.yml
# ============================================================

test_d26() {
    start_test "D26" "enforce_file_baseline"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_file_baseline.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "chmod 0666 /etc/ssh/sshd_config"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "stat -c '%a %U %G %n' /etc/ssh/sshd_config; test \"\$(stat -c '%a' /etc/ssh/sshd_config)\" = 666"
    pause_for_screenshot "D26_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_file_baseline.yml" --limit edge
    pause_for_screenshot "D26_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "stat -c '%a %U %G %n' /etc/ssh/sshd_config; test \"\$(stat -c '%a' /etc/ssh/sshd_config)\" = 600; test \"\$(stat -c '%U:%G' /etc/ssh/sshd_config)\" = root:root"
    pause_for_screenshot "D26_C_po_remediacji"

    finish_test
}

# ============================================================
# D27 - enforce_sudo_baseline.yml
# ============================================================

test_d27() {
    start_test "D27" "enforce_sudo_baseline"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_sudo_baseline.yml" --limit edge
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "printf 'ansible ALL=(ALL) ALL\\n' > /etc/sudoers.d/ansible-user; chmod 0440 /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers.d/ansible-user"
    stage "3. Potwierdz dryft" ansible edge -i "${INVENTORY}" -b -m shell -a "cat /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers.d/ansible-user; ! grep -q 'NOPASSWD' /etc/sudoers.d/ansible-user"
    pause_for_screenshot "D27_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_sudo_baseline.yml" --limit edge
    pause_for_screenshot "D27_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible edge -i "${INVENTORY}" -b -m shell -a "cat /etc/sudoers.d/ansible-user; stat -c '%a %U %G' /etc/sudoers.d/ansible-user; visudo -cf /etc/sudoers; sudo -l -U ansible; grep -q '^ansible ALL=(ALL) NOPASSWD:ALL$' /etc/sudoers.d/ansible-user; test \"\$(stat -c '%a' /etc/sudoers.d/ansible-user)\" = 440; test \"\$(stat -c '%U:%G' /etc/sudoers.d/ansible-user)\" = root:root"
    pause_for_screenshot "D27_C_po_remediacji"

    finish_test
}

# ============================================================
# D28 - enforce_version_baseline.yml
# ============================================================

test_d28() {
    start_test "D28" "enforce_version_baseline"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_version_baseline.yml" --limit scanner
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "apt-mark unhold nmap || true; DEBIAN_FRONTEND=noninteractive apt-get remove -y nmap"
    stage "3. Potwierdz dryft" ansible scanner -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' nmap 2>/dev/null || echo NMAP_UNKNOWN; ! dpkg-query -W -f='\${Status}\n' nmap 2>/dev/null | grep -Eq '^[^ ]+ ok installed$'"
    pause_for_screenshot "D28_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/enforce_version_baseline.yml" --limit scanner
    pause_for_screenshot "D28_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" ansible scanner -i "${INVENTORY}" -b -m shell -a "dpkg-query -W -f='\${Status} \${Version}\\n' nmap; dpkg --get-selections nmap; test \"\$(dpkg-query -W -f='\${Version}' nmap)\" = '7.99+dfsg-1kali1'; dpkg --get-selections nmap | grep -q '[[:space:]]hold$'"
    pause_for_screenshot "D28_C_po_remediacji"

    finish_test
}

# ============================================================
# D29 - rotate_passwords.yml (test inwariantu)
# ============================================================

test_d29() {
    start_test "D29" "rotate_passwords"

    stage "1. Ustal stan poprawny" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/rotate_passwords.yml" -e "password_target=edge"
    block_if_baseline_failed && return

    stage "2. Wprowadz kontrolowany dryft" chmod 0644 "${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass"
    stage "3. Potwierdz dryft" bash -c "stat -c '%a %U %G %n' '${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass'; test \"\$(stat -c '%a' '${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass')\" = 644"
    pause_for_screenshot "D29_A_dryft"

    stage "4. Uruchom remediacje" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_DIR}/rotate_passwords.yml" -e "password_target=edge"
    pause_for_screenshot "D29_B_ansible"

    stage "5. Zweryfikuj stan po remediacji" bash -c "stat -c '%a %U %G %n' '${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass'; head -n 1 '${ROOT_DIR}/inventories/host_vars/edge/secrets.pass'; test \"\$(stat -c '%a' '${ROOT_DIR}/inventories/.vault_passwords/generated_admin_secrets.pass')\" = 600; head -n 1 '${ROOT_DIR}/inventories/host_vars/edge/secrets.pass' | grep -q '^\\\$ANSIBLE_VAULT;'"
    pause_for_screenshot "D29_C_po_remediacji"

    if (( CURRENT_FAILED == 0 )); then
        finish_test "PASS - inwariant"
    else
        finish_test "FAIL"
    fi
}

# ============================================================
# URUCHOMIENIE TESTOW W KOLEJNOSCI PROCEDUR DRYFTU
# ============================================================

for n in $(seq -w 1 29); do
    id="D${n}"
    if should_run "${id}"; then
        "test_d${n}"
    fi
done

# ============================================================
# PODSUMOWANIE
# ============================================================

{
    echo
    line
    echo " PODSUMOWANIE TESTOW DRYFTU"
    line
    printf '%-5s | %-43s | %s\n' "ID" "PLAYBOOK / TEST" "WYNIK"
    printf '%-5s-+-%-43s-+-%s\n' "-----" "-------------------------------------------" "-------------------------"

    for i in "${!RESULT_IDS[@]}"; do
        printf '%-5s | %-43s | %s\n' "${RESULT_IDS[$i]}" "${RESULT_NAMES[$i]}" "${RESULT_STATUS[$i]}"
    done

    echo
    echo "Raporty: ${REPORT_DIR}"
    echo "Log zbiorczy: ${MASTER_LOG}"
    echo "Liczba FAIL/BLOCKED: ${TOTAL_FAILURES}"
} | tee "${SUMMARY_FILE}"

if (( TOTAL_FAILURES > 0 )); then
    exit 1
fi

exit 0
