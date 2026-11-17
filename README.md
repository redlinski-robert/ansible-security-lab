# Ansible Lab

Projekt laboratoryjny do konfiguracji i testowania srodowiska za pomoca
Ansible. Inventory obejmuje maszyny `edge` i `app` w grupie `blue_group` oraz
`scanner` w grupie `red_group`. Playbooki konfiguruja m.in. systemy, konta,
uslugi i zabezpieczenia. Repozytorium etckeeper na hostach pozwala sledzic
zmiany w `/etc`.

Projekt jest przeznaczony do kontrolowanego laboratorium. Playbooki i skrypty
testowe moga zmieniac konfiguracje, konta i hasla, instalowac pakiety oraz
restartowac maszyny. Przed uruchomieniem sprawdz ich zakres i przygotuj
mozliwosc przywrocenia srodowiska. W `ansible.cfg` wylaczono sprawdzanie
kluczy hostow SSH na potrzeby laboratorium.

## Struktura projektu

- `inventories/` - hosty, grupy i ich zmienne.
- `playbooks/` - playbooki, wspolne zadania, szablony i pliki aplikacji.
- `procedures/functional/` i `procedures/drift/` - reczne procedury testowe.
- `procedures/global/auditability.md` - procedura audytowalnosci etckeeper.
- `test_*.sh` - skrypty testowe. Czesc zapisuje wyniki w `reports/`.
- `logs/` - katalog logow Ansible wskazany w `ansible.cfg`.

Zawartosc `logs/` i `reports/` jest ignorowana przez Git, ale same katalogi
pozostaja w repozytorium dzieki plikom `.gitignore`. Wygenerowane logi i raporty
moga zawierac dane srodowiska, dlatego przed udostepnieniem ich nalezy je
sprawdzic.

## Konfiguracja przed uruchomieniem

Wartosci oznaczone jako `__UZUPELNIJ_...__` sa znacznikami do recznego
zastapienia, a nie zmiennymi Ansible. Projekt nie jest gotowy do uruchomienia,
dopoki nie zostana uzupelnione wartosci wymagane przez wybrany playbook lub
skrypt. Wyszukaj `__UZUPELNIJ_` w calym projekcie i zastap wszystkie
wystapienia danego znacznika odpowiednia wartoscia:

| Znacznik | Wymagana wartosc |
| --- | --- |
| `__UZUPELNIJ_NAZWA_PROJEKTU__` | Nazwa projektu (domyślnie nazwa katalogu głównego projektu) |
| `__UZUPELNIJ_DOMENA_APLIKACJI__` | Nazwa domeny podatnej aplikacji do testów |
| `__UZUPELNIJ_UZYTKOWNIK_KONTROLERA__` | Uzytkownik na wezle sterujacym |
| `__UZUPELNIJ_GRUPE_KONTROLERA__` | Grupa na wezle sterujacym |
| `__UZUPELNIJ_UZYTKOWNIK_BLUE__` | Dotychczasowy uzytkownik hostow blue |
| `__UZUPELNIJ_UZYTKOWNIK_RED__` | Dotychczasowy uzytkownik hostow red |
| `__UZUPELNIJ_SCIEZKE_KLUCZA_SSH__` | Pelna sciezka do klucza prywatnego SSH na kontrolerze |
| `__UZUPELNIJ_SIEC_LAB_CIDR__` | Siec laboratoryjna w zapisie CIDR |
| `__UZUPELNIJ_IP_BRAMY__` | Adres IP bramy |
| `__UZUPELNIJ_IP_KONTROLERA__` | Adres IP kontrolera i serwera Zabbix |
| `__UZUPELNIJ_IP_EDGE__` | Adres IP hosta edge |
| `__UZUPELNIJ_IP_APP__` | Adres IP hosta app |
| `__UZUPELNIJ_IP_SCANNER__` | Adres IP hosta scanner |
| `__UZUPELNIJ_HASH_COMMITA__` | Hash wybranego commita w recznej procedurze audytowalnosci |

Adresy hostow wystepuja zarowno w `inventories/hosts.yml`, jak i w
`inventories/host_vars/`. Wartosci w `host_vars` maja wyzszy priorytet.
Uzupelnij tez powtorzenia w skryptach, konfiguracji aplikacji i procedurach.
Pozostale parametry, w tym porty SSH, wersje pakietow i dostep do sudo, nalezy
dostosowac do wlasnego srodowiska.

Na maszynie sterujacej z zainstalowanym Ansible, z katalogu glownego projektu,
sprawdz inventory i polaczenie:

```bash
ansible-inventory -i inventories/hosts.yml --graph
ansible all -i inventories/hosts.yml -m ping
```

Przed wykonaniem playbooka zapoznaj sie z jego zmiennymi i procedura testowa.
`ansible.cfg` wskazuje `logs/ansible.log`, dlatego katalog `logs/` musi istniec.

## Jak czytac playbooki

Playbook to plik YAML opisujacy jeden lub kilka przebiegow (play). `hosts`
wybiera hosty lub grupy z inventory, `become` wlacza podniesienie uprawnien,
a `gather_facts` decyduje o zebraniu informacji o systemie. `vars` zawiera
zmienne danego przebiegu. Inne wartosci moga pochodzic z inventory lub z
parametrow uruchomienia. Wyrazenia `{{ ... }}` sa obliczane przez Ansible.

Zadania (`tasks`) wykonuja moduly Ansible na wybranych hostach, zwykle w
kolejnosci zapisu. `register` zapisuje wynik zadania, `when` warunkuje jego
wykonanie, a `loop` powtarza je dla kolejnych elementow. `set_fact` ustala
zmienne na czas przebiegu. `delegate_to: localhost` wykonuje zadanie na
kontrolerze zamiast na hoscie docelowym. `include_tasks` dolacza wspolne
zadania, `notify` zglasza handler do wykonania po zmianie, a `block`,
`rescue` i `always` grupuja operacje, obsluge bledow i zadania koncowe.
`changed_when` i `failed_when` okreslaja sposob oceny wyniku zadania.

Wiele playbookow korzysta z `package_guard_*`: najpierw sprawdza pakiety,
ewentualnie zdejmuje blokade APT `hold`, instaluje wymagane wersje i ponownie
ustawia blokade. Zadania `commit_etckeeper.yml` sprawdzaja stan `/etc` i
probuja zapisac zmiany w repozytorium etckeeper, jesli jest dostepny. Ich
wywolanie nie oznacza, ze kazdy playbook koniecznie utworzy commit.

## Uruchamianie calej sekwencji - run_all

[run_all.sh](run_all.sh) jest skryptem zbiorczym do konfiguracji laboratorium,
a nie osobnym testem. Ustawia `ANSIBLE_CONFIG` na konfiguracje projektu
i uruchamia playbooki w zapisanej kolejnosci, w czterech etapach:

1. Stan bazowy i inicjalizacja: ustawienia aktualizacji i sieci, etckeeper,
   banner oraz zmiany kont, grup i hasel.
2. Infrastruktura i hardening: Docker, Nginx, AppArmor, restart hostow,
   zabezpieczenia Docker i SSH, Fail2Ban, firewall oraz aktualizacje pakietow.
3. Wdrozenie aplikacji.
4. Weryfikacja, monitoring i utrzymanie: Lynis, Nmap, Hydra, Nikto, Zabbix,
   egzekwowanie wzorcowej konfiguracji plikow, sudo i wersji pakietow oraz
   rotacja hasel.

Przed tymi etapami skrypt sprawdza konfiguracje i inventory, wlacza NTP
oraz tworzy grupe `my-test-group`, konto `my-test-user` i wpis sudo dla tego
konta. Przed uzyciem uzupelnij znaczniki, sprawdz parametry playbookow
i zapewnij mozliwosc przywrocenia maszyn. Sekwencja zmienia takze konto
polaczeniowe Ansible, usuwa stare konta i moze zmienic dostep sieciowy.

W obecnej wersji skrypt zawiera literowke `cd "${ROOT_DIR}"4`. Przed
uruchomieniem trzeba usunac koncowe `4`. Inaczej zwykle zakonczy sie
na probie wejscia do nieistniejacego katalogu.

Po tej korekcie uruchom go przez Bash na kontrolerze Ansible:

```bash
bash run_all.sh
```

Skrypt zatrzymuje sie przy bledzie polecenia i nie cofa wykonanych zmian.
Nie wznawia tez automatycznie pracy od przerwanego etapu. Moze wymagac
interakcji, w tym hasla sudo (`-K` przy instalacji i tescie Zabbix Get).
Nie uruchamia skryptow `test_*.sh` ani nie tworzy zbiorczego raportu testow.
Komunikat koncowy potwierdza wykonanie sekwencji, nie zaliczenie wszystkich
kryteriow opisanych w procedurach.

## Testy

Testy rozdzielaja kilka pytan: czy playbooki wykonuja sie bez bledow, czy
uslugi dzialaja, czy zabezpieczenia wspolpracuja, czy ponowne wykonanie
powoduje zbedne zmiany i czy konfiguracja jest naprawiana po dryfcie.
Testy obejmuja tez mozliwosc odtworzenia historii zmian w `/etc`.

Procedury w [procedures/functional/](procedures/functional/) i
[procedures/drift/](procedures/drift/) podaja komendy, oczekiwane wyniki
i kryteria oceny poszczegolnych przypadkow. Skrypty automatyzuja wybrane
kroki, ale nie zastepuja wszystkich kontroli recznych.

### Co sprawdzaja skrypty

| Skrypt | Dzialanie i sposob oceny |
| --- | --- |
| [test_functional_basic.sh](test_functional_basic.sh) | Uruchamia sekwencje playbookow. Potwierdza ich wykonanie bez bledu, ale nie dodaje osobnych kontroli dzialania uslug. |
| [test_functional_advanced.sh](test_functional_advanced.sh) | Po playbookach wykonuje dodatkowe kontrole: m.in. skladni konfiguracji, stanu uslug, kont, polaczenia SSH, kontenerow, odpowiedzi aplikacji i agenta Zabbix. Wyswietla `PASS` lub `FAIL` dla polecen kontrolnych. |
| [test_functional_relational.sh](test_functional_relational.sh) | Bada zaleznosci miedzy kolejnymi zmianami: haslami i ich rotacja, hardeningiem SSH, Fail2Ban, skanowaniem uslug oraz firewallem. Kolejne etapy korzystaja ze stanu pozostawionego przez poprzednie. |
| [test_idempotency.sh](test_idempotency.sh) | Uruchamia kazdy playbook dwukrotnie, z przerwami na analize wynikow. Nie porownuje automatycznie podsumowan Ansible ani nie sprawdza warunku `changed=0`. |
| [test_drift.sh](test_drift.sh) | Ustala stan bazowy, wprowadza kontrolowana niezgodnosc, potwierdza ja, uruchamia remediacje i sprawdza efekt. Obejmuje przypadki D01-D29. Mozna wybrac pojedyncze testy. |
| [test_lynis.sh](test_lynis.sh) | Uruchamia Lynis na poczatku i ponownie w trakcie sekwencji playbookow. Rejestruje statusy, kody zakonczenia i czas wykonania playbookow. Po ich bledach kontynuuje sekwencje i na koncu zwraca blad zbiorczy. |
| [test_etckeeper_auditability.sh](test_etckeeper_auditability.sh) | Instaluje etckeeper przed trwalymi zmianami ustawien aktualizacji, wykonuje pozostale playbooki i zbiera historie oraz stan repozytoriow `/etc` na hostach. |

Test relacyjny obejmuje m.in. probe znalezienia znanego hasla z ograniczonego,
trzyhaslowego slownika, ponowienie proby po rotacji hasla, sprawdzenie
rzeczywistej blokady SSH przez Fail2Ban oraz dostepnosci portow po zmianie
regul firewalla. Wykonuje tez skany Nmap i Nikto na kolejnych etapach
konfiguracji. Brak trafienia w slowniku nie dowodzi ogolnej odpornosci hasla,
a wyniki skanow wymagaja osobnej interpretacji.

### Uruchamianie i ocena

Skrypty uruchamiaj przez Bash na kontrolerze Ansible, po uzupelnieniu
konfiguracji i sprawdzeniu dostepu SSH oraz sudo. Przyklady z katalogu
glownego projektu:

```bash
bash test_functional_advanced.sh
bash test_idempotency.sh
bash test_drift.sh D04 D17
bash test_etckeeper_auditability.sh
```

Sa to przyklady osobnych przebiegow, a nie zalecenie uruchamiania wszystkich
testow kolejno na tych samych maszynach. **Skrypty rzeczywiscie zmieniaja
srodowisko**: m.in. konta, hasla, port SSH, pakiety i reguly sieciowe. Moga
restartowac hosty. Nie cofaja automatycznie wszystkich zmian. Przygotuj
snapshoty lub inny sposob odtworzenia stanu poczatkowego oraz dostep awaryjny.
Czesc krokow wymaga interakcji, np. podania hasla sudo lub wyboru hasla
testowego. Przerwy na zrzuty ekranu nie wykonuja ich automatycznie.

Poprawne zakonczenie skryptu nie jest rownoznaczne z zaliczeniem wszystkich
wymagan. W tescie zaawansowanym `PASS` oznacza zerowy kod zakonczenia
polecenia kontrolnego. Polecenia wyswietlajace konfiguracje, uprawnienia
lub sumy plikow moga wymagac recznego porownania z procedura. Wskazane
testy negatywne i proby logowania rowniez nalezy wykonac recznie.

Przy ocenie idempotencji porownaj oba przebiegi i wyjasnij zmiany z drugiego
uruchomienia. Dla zadan utrzymujacych konfiguracje oczekiwany jest brak
zbednych zmian. Restart, skanowanie czy rotacja hasel wymagaja interpretacji
zgodnej z przeznaczeniem operacji.

W testach dryftu wynik `BLOCKED` oznacza, ze nie udalo sie ustalic stanu
bazowego i skrypt nie wprowadzil zaplanowanej niezgodnosci. Restart jest
oceniany jako osobny test operacyjny, a rotacja hasel jako test inwariantu:
uprawnien pliku klucza Vault i zaszyfrowanej postaci sekretow.

W tescie etckeeper nalezy potwierdzic obecnosc oczekiwanych zmian w historii
`/etc` i wyjasnic niezatwierdzone zmiany na kazdym hoscie. Repozytoria hostow
maja wlasne identyfikatory commitow. Brak commita dla playbooka, ktory nie
zmienil `/etc`, nie jest sam w sobie bledem. Skrypt zbiera dane, ale nie
wystawia automatycznego wyniku zaliczenia. Raportowanie nie tworzy commitow.
Instrukcja wykonania i recznej oceny znajduje sie w
[procedures/global/auditability.md](procedures/global/auditability.md).

### Raporty

Wybrane skrypty zapisuja wyniki w [reports/](reports/), w katalogach lub
plikach ze znacznikiem czasu:

| Test | Zapisane wyniki |
| --- | --- |
| Relacyjny | `reports/functional_relational/DATA_CZAS/`: logi poszczegolnych uruchomien playbookow i `summary.csv`. Raporty narzedzi trafiaja osobno do katalogow Hydra, Nmap i Nikto. CSV opisuje wykonanie playbookow, nie wszystkie dodatkowe asercje skryptu. |
| Dryft | `reports/drift/DATA_CZAS/`: log zbiorczy `drift_full.log`, logi przypadkow i podsumowanie `summary.txt`. |
| Lynis | `reports/test_lynis_DATA_CZAS.csv`: status, kod zakonczenia i czas wykonania playbooka. Sam playbook audytowy pobiera raporty Lynis do `reports/lynis/`. |
| Etckeeper | `reports/etckeeper_auditability/DATA_CZAS/`: `commits_full.log` (historia ze statystykami), `commits_list.log` (lista commitow), `commits_summary.log` (klasyfikacja `[PUSTY]` / `[ZAPELNIONY]` wedlug zmian wykrytych przez Git) i `working_tree_status.log` (niezatwierdzone zmiany). Raport koncowy moze nie powstac, jesli sekwencja przerwie sie wczesniej. |

Zestawienie CSV testu Lynis opisuje powodzenie wykonania playbookow, nie
wynik bezpieczenstwa systemu. Wskaznik hardeningu i ustalenia audytu oceniaj
na podstawie raportow Lynis. Skrypt nie wykonuje audytu po kazdej zmianie
ani po calej koncowej konfiguracji.

Przed udostepnieniem raportow sprawdz ich zawartosc pod katem danych
srodowiska i sekretow.

## Pomocniczy skrypt RunVM

`RunVM.ps1` nie jest wymagany przez projekt Ansible ani z nim zintegrowany.
Zostal pozostawiony jako ciekawostka:
ulatwia szybki powrot maszyn VirtualBox do konkretnych snapshotow, ponowne
skopiowanie kodu i przeprowadzenie testow.

Przed ewentualnym uzyciem trzeba dostosowac konfiguracje skryptu do wlasnej
instalacji: sciezki, uzytkownika, maszyny, snapshoty, adapter i polaczenie SSH.
Skrypt wylacza maszyny, przywraca snapshoty i zmienia konfiguracje sieci.
**Usuwa tez wskazany zdalny katalog projektu przed skopiowaniem nowej wersji**.
Nalezy sprawdzic sciezke i zabezpieczyc potrzebne dane. Uzytkownik i grupa
kontrolera moga miec rozne nazwy, a sciezki `/home/...` trzeba dopasowac,
jesli katalog domowy znajduje sie gdzie indziej.

## Przed publikacja

Playbook `harden_nginx.yml` zachowuje publiczny adres GitHub autora jako
awaryjne zrodlo pakietu. Sprawdz sekrety, lokalne pliki, zaleznosci, logi,
raporty i historie Git. Same znaczniki nie anonimizuja historii ani innych
danych, ktore mogly tam trafic.
