# F02 - change_netplan.yml

Testuj z konsola VM lub aktywna druga sesja. Po uruchomieniu playbooka, z maszyny `management` wykonaj:



Sprawdz w wynikach plik zarzadzany przez playbook: musi zawierac wlasciwy interfejs oraz serwery DNS `8.8.8.8` i `1.1.1.1`.

Jesli na Kali wlaczyles migracje starej konfiguracji `systemd-networkd`, sprawdz jej backup osobno:



Brak pliku `*.pre-netplan.bak` jest poprawny, jesli migracja nie byla wlaczona lub nie istnial poprzedni plik `/etc/systemd/network/10-nat.network`.

`getent ahosts` jest wlasciwym testem DNS dla wszystkich hostow. Dodatkowy podglad konfiguracji resolvera wykonaj tylko na hostach uzywajacych `systemd-resolved`:



Na Kali `resolvectl` moze nie byc zainstalowany. Komunikat `No such file or directory` dla tego polecenia nie oznacza bledu konfiguracji DNS.
## 1) Test generowania konfiguracji Netplan

```bash
ansible all -b -m command -a "netplan generate"
```

Wyjasnienie: ta komenda sprawdza, czy Netplan potrafi poprawnie wygenerowac konfiguracje z aktualnego YAML-a bez bledow skladniowych. To pierwszy test, czy zmiany w konfiguracji sa poprawne zanim system przejdzie do aktywnego zastosowania.

## 2) Test aktualnego stanu sieci po wygenerowaniu

```bash
ansible all -b -m command -a "netplan get"
```

Wyjasnienie: `netplan get` pokazuje aktywna, finalna konfiguracje sieci po przetworzeniu pliku. To pozwala latwo sprawdzic, czy interfejs, adresy i DNS sa dokladnie takie, jakie mialy byc ustawione przez playbook.

## 3) Test rozwiazywania nazw DNS

```bash
ansible all -b -m command -a "getent ahosts security.ubuntu.com"
```

Wyjasnienie: ta komenda sprawdza, czy system poprawnie rozwiazuje nazwy DNS i czy konfiguracja adresow serwerow DNS dziala w praktyce. To jest kontrola funkcjonalna, bo sam plik YAML nie dowodzi, ze nazwy faktycznie sie rozwiaza.

## 4) Test listowania plikow Netplan

```bash
ansible all -b -m command -a "ls -l /etc/netplan"
```

Wyjasnienie: ta komenda sprawdza, ktory plik Netplan jest faktycznie w katalogu i czy ma poprawne wlascicielstwo oraz uprawnienia. To pomaga potwierdzic, ze konfiguracja jest zapisana tam, gdzie system ja odczyta.

## 5) Test tresci pliku konfiguracji sieciowej

```bash
ansible all -b -m command -a "cat /etc/netplan/*.yaml"
```

Wyjasnienie: ta komenda czyta dokladnie zapisany YAML sieciowy, wiec mozna sprawdzic, czy interfejs i serwery DNS sa ustawione zgodnie z oczekiwaniami. To jest najbezposredniejsza kontrola tego, co system rzeczywiscie uzywa.

## 6) Test backupu konfiguracji systemd-networkd

```bash
ansible scanner -b -m shell -a "ls -l /etc/systemd/network/*.pre-netplan.bak"
```

Wyjasnienie: ta komenda sprawdza, czy backup poprzedniej konfiguracji zostal utworzony tam, gdzie powinien istniec. To pomaga potwierdzic, ze migracja konfiguracji byla bezpieczna i ze nie utracono poprzedniego ustawienia.

## 7) Test statusu resolvera

```bash
ansible blue_group -b -m command -a "resolvectl status"
```

Wyjasnienie: ta komenda pokazuje aktywny stan resolvera DNS i podlaczonych interfejsow. To potwierdza, czy system korzysta z poprawnych serwerow DNS i czy konfiguracja nie zostala naruszona po zmianie Netplan.

## 8) Test faktycznej lacznosci internetowej (DNS + apt)

```bash
ansible scanner -b -m shell -a "getent ahosts http.kali.org; apt-get update"
```

Wyjasnienie: `getent ahosts` i `apt-get update` na hoscie z NAT-owym interfejsem sprawdzaja nie tylko sam wpis DNS, ale tez realna trase do internetu (adres, brama, DNS). To wykrywa przypadki, gdy interfejs NAT istnieje, ale pozostaje administracyjnie `DOWN` po starcie VM (np. swiezo dodany adapter), co playbook z zalozenia naprawia automatycznie.

## Test funkcjonalnosci

**PASS**: YAML jest poprawny, wskazane DNS-y sa efektywne i nazwa sie rozwiazuje po ponownym uruchomieniu hosta. Jesli playbook zastepowal wczesniejsza konfiguracje, backup jest czytelny.

**FAIL**, jesli playbook zmodyfikowal niewlasciwy z kilku plikow.

