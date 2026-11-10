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

## Testy i audytowalnosc

Procedury w `procedures/` podaja komendy i kryteria oceny poszczegolnych
testow. Skrypt `test_etckeeper_auditability.sh` uruchamia sekwencje playbookow,
a nastepnie zbiera historie i stan repozytoriow etckeeper w
`reports/etckeeper_auditability/DATA_CZAS/`. Instrukcja wykonania i recznej
oceny znajduje sie w `procedures/global/auditability.md`.

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
