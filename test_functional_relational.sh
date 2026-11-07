#!/usr/bin/env bash

# Test relacyjny: w odroznieniu od testu idempotentnosci, kolejne kroki
# celowo zmieniaja stan srodowiska (hasla, port SSH, firewall...) i kazdy
# kolejny krok zaklada stan pozostawiony przez poprzedni (stad "relacyjny").

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="${ROOT_DIR}/playbooks"
REPORT_DIR="${ROOT_DIR}/reports"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
PLAYBOOK_LOG_DIR="${REPORT_DIR}/functional_relational/${RUN_ID}"
SUMMARY_FILE="${PLAYBOOK_LOG_DIR}/summary.csv"

# Slownik testowy kopiowany na scanner jako podmienka pod rockyou.txt, zeby Hydra
# atakowala tylko trzema znanymi haslami zamiast prawdziwego rockyou.txt.
HYDRA_TEST_PASSWORD_FILE="${PLAYBOOK_DIR}/input/hydra_test_passwords.txt"
HYDRA_TEST_PASSWORD_GZIP="${HYDRA_TEST_PASSWORD_FILE}.gz"
HYDRA_TEST_ROCKYOU_PATH="/tmp/relational-rockyou.txt"
HYDRA_WORDLIST_STAGED=false
export ANSIBLE_CONFIG="${ROOT_DIR}/ansible.cfg"
cd "${ROOT_DIR}"

mkdir -p "${PLAYBOOK_LOG_DIR}"
printf 'sequence,playbook,status,exit_code,log_file\n' > "${SUMMARY_FILE}"
PLAYBOOK_RUN_COUNT=0

# Daje czas na zrobienie zrzutu ekranu miedzy krokami podczas nagrywania demo.
pause_for_screenshot() {
    echo "10 sekund na zrzut ekranu..."
    sleep 10
}

# Usuwa testowy slownik haszy ze scannera, nawet jesli playbook Hydry sie wywalil.
cleanup_hydra_wordlist() {
    rm -f "${HYDRA_TEST_PASSWORD_GZIP}"
    if [[ "${HYDRA_WORDLIST_STAGED}" == true ]]; then
        ansible scanner -m file -a \
            "path=${HYDRA_TEST_ROCKYOU_PATH} state=absent" >/dev/null 2>&1 || true
        ansible scanner -m file -a \
            "path=${HYDRA_TEST_ROCKYOU_PATH}.gz state=absent" >/dev/null 2>&1 || true
        HYDRA_WORDLIST_STAGED=false
    fi
}

trap cleanup_hydra_wordlist EXIT

# Uruchamia jeden playbook, loguje pelne wyjscie do pliku, a na ekran przepuszcza
# tylko istotne linie (PLAY/TASK/wyniki), i dopisuje wpis do summary.csv.
run_playbook() {
    local playbook="$1"
    shift
    local sequence log_file exit_code status

    if [[ ! -f "${PLAYBOOK_DIR}/${playbook}" ]]; then
        echo "ERROR: Nie znaleziono playbooka: ${PLAYBOOK_DIR}/${playbook}"
        exit 1
    fi

    PLAYBOOK_RUN_COUNT=$((PLAYBOOK_RUN_COUNT + 1))
    printf -v sequence '%02d' "${PLAYBOOK_RUN_COUNT}"
    log_file="${PLAYBOOK_LOG_DIR}/${sequence}_${playbook//\//_}.log"

    echo
    echo "============================================================"
    echo " URUCHAMIAM: ${playbook} [${sequence}]"
    echo " Pelny log: ${log_file}"
    echo "============================================================"

    if ansible-playbook "${PLAYBOOK_DIR}/${playbook}" "$@" \
        2> >(tee -a "${log_file}" >&2) \
        | tee "${log_file}" \
        | awk '
            /^PLAY / || /^TASK / || /^PLAY RECAP/ ||
            /^BECOME password:/ || /^SSH password:/ || /^Vault password:/ ||
            /^ERROR!/ || /^fatal:/ ||
            /^(ok|changed|skipping|failed|unreachable|rescued|ignored):/ ||
            / \| (CHANGED|SUCCESS|FAILED|UNREACHABLE|SKIPPED|OK)( \||$)/ {
                print
                fflush()
            }
        '; then
        exit_code=0
        status=PASS
    else
        exit_code=$?
        status=FAIL
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi

    printf '%s,"%s",%s,%s,"%s"\n' \
        "${sequence}" "${playbook}" "${status}" "${exit_code}" "${log_file}" >> "${SUMMARY_FILE}"
    echo "WYNIK PLAYBOOKA: ${status} (kod ${exit_code})"
    pause_for_screenshot
}

# Uruchamia lokalna funkcje/komende jako pojedynczy test PASS/FAIL (bez ansible-playbook).
run_local_check() {
    local description="$1"
    shift

    echo
    echo "------------------------------------------------------------"
    echo " TEST: ${description}"
    echo "------------------------------------------------------------"

    if "$@"; then
        echo "PASS: ${description}"
    else
        echo "FAIL: ${description}"
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi
    pause_for_screenshot
}

# Podmienia rockyou.txt na scannerze na 3-haslowy slownik testowy, uruchamia atak
# Hydry na dany port SSH, po czym zawsze sprzata slownik ze scannera.
run_hydra_attack() {
    local ssh_port="$1"
    local use_nmap_input="$2"
    local status=0

    sed 's/\r$//' "${HYDRA_TEST_PASSWORD_FILE}" | gzip -c > "${HYDRA_TEST_PASSWORD_GZIP}"
    HYDRA_WORDLIST_STAGED=true
    ansible scanner -m copy -a \
        "src=${HYDRA_TEST_PASSWORD_GZIP} dest=${HYDRA_TEST_ROCKYOU_PATH}.gz mode=0600"

    if run_playbook "install_hydra_or_attack.yml" -K \
        --extra-vars "{\"get_from_nmap\":${use_nmap_input},\"get_rotated_passwords\":false,\"ssh_port\":${ssh_port},\"rockyou_path\":\"${HYDRA_TEST_ROCKYOU_PATH}\"}"; then
        status=0
    else
        status=$?
    fi

    ansible scanner -m file -a \
        "path=${HYDRA_TEST_ROCKYOU_PATH} state=absent"
    ansible scanner -m file -a \
        "path=${HYDRA_TEST_ROCKYOU_PATH}.gz state=absent"
    rm -f "${HYDRA_TEST_PASSWORD_GZIP}"
    HYDRA_WORDLIST_STAGED=false

    if (( status != 0 )); then
        return "${status}"
    fi
}

run_nmap() {
    run_playbook "install_nmap_or_enumerate.yml" -K
}

# Uruchamia Nikto na podstawie hostow/portow odkrytych przez ostatni skan Nmap.
run_nikto_with_latest_nmap_input() {
    run_playbook "install_nikto_or_scan.yml" -K \
        --extra-vars '{"get_from_nmap":true}'
}

# Sprawdza w najnowszych raportach Hydry, czy haslo testowe zostalo znalezione
# (expected=found) albo celowo nie zostalo znalezione (expected=absent).
assert_hydra_test_results() {
    local expected="$1"
    local expected_password="${2:-}"
    local latest_report report_file has_match
    local report_count=0
    latest_report="$(ls -1dt "${REPORT_DIR}/hydra/"*/ 2>/dev/null | head -n 1 || true)"

    if [[ -z "${latest_report}" ]]; then
        echo "FAIL: Nie znaleziono raportu Hydra do asercji."
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
        return
    fi

    while IFS= read -r report_file; do
        [[ -n "${report_file}" ]] || continue
        report_count=$((report_count + 1))
        if [[ "${expected}" == found ]]; then
            if grep -Eiq "login:[[:space:]]*ansible[[:space:]]+password:[[:space:]]*${expected_password}([[:space:]]|$)" "${report_file}"; then
                has_match=true
            else
                has_match=false
            fi
        elif grep -Eiq 'login:[[:space:]]*ansible[[:space:]]+password:' "${report_file}"; then
            has_match=true
        else
            has_match=false
        fi

        if [[ "${expected}" == found && "${has_match}" == true ]]; then
            echo "PASS: Hydra znalazla testowe haslo na $(basename "${report_file}")."
        elif [[ "${expected}" == absent && "${has_match}" == false ]]; then
            echo "PASS: Hydra nie znalazla hasla na $(basename "${report_file}")."
        else
            echo "FAIL: Oczekiwano wyniku '${expected}' w $(basename "${report_file}")."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))
        fi
        pause_for_screenshot
    done < <(find "${latest_report}" -maxdepth 1 -type f -name 'hydra_*.txt' -print)

    if (( report_count < 2 )); then
        echo "FAIL: Oczekiwano raportow Hydra dla edge i app; znaleziono ${report_count}."
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi
}

# Sprawdza, ze scanner nie widzi juz portow uslug na edge/app po zablokowaniu go w firewallu.
check_scanner_blocked() {
    local target port host_ip

    for target in edge app; do
        host_ip="$(ansible-inventory --host "${target}" | sed -n 's/.*"ansible_host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        port=443
        if [[ "${target}" == app ]]; then
            port=8443
        fi

        echo
        echo "------------------------------------------------------------"
        echo " TEST: scanner zablokowany na ${target}:${port}"
        echo "------------------------------------------------------------"

        if [[ -z "${host_ip}" ]]; then
            echo "FAIL: Nie mozna odczytac ansible_host dla ${target}."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))
        elif ansible scanner -m shell -a \
            "nmap -Pn -p ${port} ${host_ip} | grep -Eq '^${port}/tcp[[:space:]]+(filtered|closed)([[:space:]]|$)'"; then
            echo "PASS: scanner nie ma dostepu do ${target}:${port}."
        else
            echo "FAIL: scanner nadal widzi otwarty port ${target}:${port}."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))
        fi
        pause_for_screenshot
    done
}

check_fail2ban_ssh_blocked() {
    local target host_ip

    for target in edge app; do
        host_ip="$(ansible-inventory --host "${target}" | sed -n 's/.*"ansible_host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

        echo
        echo "------------------------------------------------------------"
        echo " TEST: Fail2Ban blokuje scanner na ${target}:${HARDENED_SSH_PORT}"
        echo "------------------------------------------------------------"

        if [[ -z "${host_ip}" ]]; then
            echo "FAIL: Nie mozna odczytac ansible_host dla ${target}."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))

        elif ansible scanner -m shell -a \
            "nmap -Pn -p ${HARDENED_SSH_PORT} ${host_ip} | grep -Eq '^${HARDENED_SSH_PORT}/tcp[[:space:]]+(filtered|closed)([[:space:]]|$)'"; then

            echo "PASS: Fail2Ban faktycznie blokuje scanner na ${target}:${HARDENED_SSH_PORT}."

        else
            echo "FAIL: Port ${HARDENED_SSH_PORT} na ${target} nadal jest dostepny ze scannera."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))
        fi

        pause_for_screenshot
    done
}

# Sprawdza w najnowszym raporcie Nmap, czy port agenta Zabbix (10050/tcp) jest widoczny jako otwarty.
check_zabbix_port_in_latest_nmap() {
    local latest_report target host_ip report_file
    latest_report="$(ls -1dt "${REPORT_DIR}/nmap/"*/ 2>/dev/null | head -n 1 || true)"

    if [[ -z "${latest_report}" ]]; then
        echo "FAIL: Nie znaleziono raportu Nmap do sprawdzenia portu Zabbix."
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
        return
    fi

    for target in edge app; do
        host_ip="$(ansible-inventory --host "${target}" | sed -n 's/.*"ansible_host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        report_file="$(find "${latest_report}" -maxdepth 1 -type f -name "*_${host_ip}.txt" -print -quit)"

        if [[ -z "${host_ip}" || -z "${report_file}" ]]; then
            echo "FAIL: Brak raportu Nmap dla hosta ${target}."
            CHECK_FAILURES=$((CHECK_FAILURES + 1))
        else
            run_local_check "Port 10050/tcp agenta Zabbix na ${target}" \
                grep -Eq '^10050/tcp[[:space:]]+open([[:space:]]|$)' "${report_file}"
        fi
    done
}

CHECK_FAILURES=0

## Fail2ban z poprzedniego uruchomienia moglby wciaz blokowac scanner (ban jest
## zdejmowany dopiero po tescie fail2ban), co falszywie psuloby pierwszy test Hydry.
#SCANNER_IP="$(ansible-inventory --host scanner | sed -n 's/.*"ansible_host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
#if [[ -n "${SCANNER_IP}" ]]; then
#    ansible blue_group -b -m command -a \
#        "fail2ban-client set sshd unbanip ${SCANNER_IP}" >/dev/null 2>&1 || true
#fi

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
pause_for_screenshot

# ============================================================
# Wylaczenie unattended-updates
# ============================================================

echo
echo "============================================================"
echo " Disable unattended-updates"
echo "============================================================"
echo
run_playbook "disable_unattended_updates.yml"

# Nmap/Hydra przed harden_ssh uzywaja portu SSH aktualnego przed zmiana.
# Port pobierany jest z group_vars/all (ansible_port), a nie wpisywany na sztywno.
INVENTORY_SSH_PORT="$(ansible-inventory --host edge | sed -n 's/.*"ansible_port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
INITIAL_SSH_PORT="${INITIAL_SSH_PORT:-${INVENTORY_SSH_PORT:-22}}"
read -r -p "Port SSH przed harden_ssh [${INITIAL_SSH_PORT}] (zrodlo: ansible-inventory --host edge): " input_ssh_port
INITIAL_SSH_PORT="${input_ssh_port:-${INITIAL_SSH_PORT}}"
if [[ ! "${INITIAL_SSH_PORT}" =~ ^[0-9]+$ ]] || (( INITIAL_SSH_PORT < 1 || INITIAL_SSH_PORT > 65535 )); then
    echo "ERROR: Nieprawidlowy port SSH: ${INITIAL_SSH_PORT}"
    exit 1
fi

# Docelowy port SSH po harden_ssh.yml. Domyslnie odczytywany z custom_ssh_port
# w samym playbooku (jedyne miejsce, w ktorym ta wartosc jest zdefiniowana),
# zamiast trzymania osobnej, latwej do rozjechania sie kopii na sztywno w tym skrypcie.
HARDEN_SSH_PLAYBOOK_FILE="${PLAYBOOK_DIR}/harden_ssh.yml"
PLAYBOOK_HARDENED_SSH_PORT="$(sed -n 's/^[[:space:]]*custom_ssh_port:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${HARDEN_SSH_PLAYBOOK_FILE}" | head -n 1)"
HARDENED_SSH_PORT="${HARDENED_SSH_PORT:-${PLAYBOOK_HARDENED_SSH_PORT:-2228}}"
read -r -p "Port SSH po harden_ssh [${HARDENED_SSH_PORT}] (zrodlo: custom_ssh_port w harden_ssh.yml): " input_hardened_ssh_port
HARDENED_SSH_PORT="${input_hardened_ssh_port:-${HARDENED_SSH_PORT}}"
if [[ ! "${HARDENED_SSH_PORT}" =~ ^[0-9]+$ ]] || (( HARDENED_SSH_PORT < 1 || HARDENED_SSH_PORT > 65535 )); then
    echo "ERROR: Nieprawidlowy port SSH: ${HARDENED_SSH_PORT}"
    exit 1
fi

# ============================================================
# HASLO: PRZED I PO ROTACJI
# ============================================================

mapfile -t HYDRA_TEST_PASSWORDS < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; s/\r$//' "${HYDRA_TEST_PASSWORD_FILE}")
if (( ${#HYDRA_TEST_PASSWORDS[@]} != 3 )); then
    echo "ERROR: ${HYDRA_TEST_PASSWORD_FILE} musi zawierac dokladnie trzy hasla testowe."
    exit 1
fi

echo "Wybierz haslo testowe do pierwszego przebiegu Hydry:"
printf '  1) Haslo testowe A\n  2) Haslo testowe B\n  3) Haslo testowe C\n'
read -r -p "Numer hasla [1-3]: " password_choice
if [[ ! "${password_choice}" =~ ^[1-3]$ ]]; then
    echo "ERROR: Wybierz 1, 2 albo 3."
    exit 1
fi
HYDRA_TEST_PASSWORD="${HYDRA_TEST_PASSWORDS[$((password_choice - 1))]}"

# Krok 1: haslo testowe znane z gory - Hydra POWINNA je znalezc (expected=found).
run_playbook "change_user_password.yml" -K \
    --extra-vars "{\"change_user_password_target\":\"blue_group\",\"target_user\":\"ansible\",\"secret_manage_password\":\"${HYDRA_TEST_PASSWORD}\"}"
run_hydra_attack "${INITIAL_SSH_PORT}" false
assert_hydra_test_results found "${HYDRA_TEST_PASSWORD}"

# Krok 2: po rotacji haslo jest juz losowe - ten sam 3-haslowy slownik nie powinien go zawierac.
# Sekrety generowane w trakcie rotacji nie powinny trafiac do logu.
run_playbook "rotate_passwords.yml" -K \
    --extra-vars '{"hide_sensitive_logs":true,"password_target":"blue_group"}'
run_hydra_attack "${INITIAL_SSH_PORT}" false
assert_hydra_test_results absent

# Krok 3: recznie ustawione mocne haslo tez nie powinno wpasc w slownik testowy.
echo "Ustaw wlasne, mocne haslo dla ansible; ten sam trzyhaslowy slownik nie powinien go zawierac."
run_playbook "change_user_password.yml" -K \
    --extra-vars '{"change_user_password_target":"blue_group","target_user":"ansible"}'
run_hydra_attack "${INITIAL_SSH_PORT}" false
assert_hydra_test_results absent

# ============================================================
# SSH: PRZED/PO HARDENINGU ORAZ FAIL2BAN
# ============================================================

# Po zahartowaniu SSH nasluchuje juz na HARDENED_SSH_PORT, a Hydra nadal nie
# powinna znalezc hasla (uzywamy targetow z ostatniego skanu Nmap).
run_playbook "harden_ssh.yml" -K \
    --extra-vars '{"ssh_target":"all"}'
run_nmap
run_hydra_attack "${HARDENED_SSH_PORT}" true
assert_hydra_test_results absent

# Powtorka po wlaczeniu fail2ban - dalej brak trafienia w slowniku.
run_playbook "install_fail2ban.yml" -K
run_hydra_attack "${HARDENED_SSH_PORT}" true
assert_hydra_test_results absent

SCANNER_IP="$(ansible-inventory --host scanner | sed -n 's/.*"ansible_host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
if [[ -z "${SCANNER_IP}" ]]; then
    echo "FAIL: Nie mozna odczytac ansible_host dla scanner; nie moge zweryfikowac Fail2ban."
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
else
    echo "Sprawdzam, czy fail2ban zbanowal scanner po probach slownika testowego."
    if ansible blue_group -b -m shell -a \
        "fail2ban-client get sshd banip | grep -F '${SCANNER_IP}'"; then
        echo "PASS: Fail2ban zablokowal adres scanner ${SCANNER_IP}."
    else
        echo "FAIL: Fail2ban nie zablokowal adresu scanner ${SCANNER_IP}."
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi
    pause_for_screenshot

    # Sprawdzenie rzeczywistego blokowania ruchu SSH.
    check_fail2ban_ssh_blocked
    pause_for_screenshot

    echo "Usuwam tymczasowy ban scanner po tescie Fail2Ban."
    
    ansible blue_group -b -m command -a \
        "fail2ban-client set sshd unbanip ${SCANNER_IP}"
    
    echo "Sprawdzam, czy scanner zostal odblokowany."
    
    if ansible blue_group -b -m shell -a \
        "fail2ban-client get sshd banip | grep -F '${SCANNER_IP}'"; then
    
        echo "FAIL: Scanner ${SCANNER_IP} nadal znajduje sie na liscie banow."
        CHECK_FAILURES=$((CHECK_FAILURES + 1))
    else
        echo "PASS: Scanner ${SCANNER_IP} zostal odblokowany."
    fi
    
    pause_for_screenshot
fi
    
# ============================================================
# Docker i Docker Compose: instalacja 
# ============================================================
run_playbook "install_docker.yml" -K

# ============================================================
# Apparmor: instalacja i reboot systemu
# ============================================================
run_playbook "install_apparmor.yml" -K
run_playbook "reboot_system.yml" -K

# ============================================================
# NGINX: SKAN PRZED I PO HARDENINGU
# ============================================================

run_playbook "install_nginx.yml" -K
run_nmap
run_nikto_with_latest_nmap_input

run_playbook "harden_nginx.yml" -K
run_nikto_with_latest_nmap_input

# ============================================================
# APLIKACJA: SKAN PRZED I PO WDROZENIU
# ============================================================

run_playbook "deploy_application.yml" -K
run_nmap
run_nikto_with_latest_nmap_input

# ============================================================
# ZABBIX: CZesCIOWY TEST NMAP PORTU AGENTA
# ============================================================

run_playbook "install_zabbix_agent.yml" -K
run_nmap
check_zabbix_port_in_latest_nmap

# ============================================================
# FIREWALL: NA KONCU, ZE SKANNEREM ZABLOKOWANYM
# ============================================================

BLOCK_SCANNER_AT_FIREWALL_TEST="${BLOCK_SCANNER_AT_FIREWALL_TEST:-true}"
if [[ "${BLOCK_SCANNER_AT_FIREWALL_TEST}" != true && "${BLOCK_SCANNER_AT_FIREWALL_TEST}" != false ]]; then
    echo "ERROR: BLOCK_SCANNER_AT_FIREWALL_TEST musi miec wartosc true albo false."
    exit 1
fi

if [[ "${BLOCK_SCANNER_AT_FIREWALL_TEST}" == true ]]; then
    run_playbook "configure_firewall.yml" -K \
        --extra-vars '{"let_scanner_hosts_connect":false}'
    check_scanner_blocked
else
    echo "Pominieto test blokady scanner: BLOCK_SCANNER_AT_FIREWALL_TEST=false."
fi


# ============================================================
# PODSUMOWANIE
# ============================================================

echo
echo "============================================================"
if (( CHECK_FAILURES > 0 )); then
    echo " TEST RELACYJNY ZAKONCZONY BLEDAMI: ${CHECK_FAILURES}"
    echo " Raporty skanow: ${REPORT_DIR}"
    echo "============================================================"
    exit 1
fi

echo " TEST RELACYJNY ZAKONCZONY"
echo " Raporty Hydra/Nmap/Nikto: ${REPORT_DIR}"
echo "============================================================"
