# F10 - install_nginx.yml

Patrz procedura w [23_harden_nginx.md](23_harden_nginx.md) - instalacja Nginx powinna byc testowana razem z jego zaostrzaniem.

Z maszyny `management` wykonaj:



Oczekuj aktywnej i wlaczonej uslugi oraz braku bledow `nginx -t`.
## 1) Test zainstalowanych pakietow nginx i openssl

```bash
ansible edge_servers -b -m command -a "dpkg-query -W nginx openssl"
```

Wyjasnienie: ta komenda sprawdza, czy oba pakiety sa zainstalowane i dostepne. To jest pierwsza kontrola, ktora potwierdza, ze srodowisko ma podstawowe zaleznosci do dzialania serwera webowego i TLS.

## 2) Test wersji Nginx

```bash
ansible edge_servers -b -m shell -a "nginx -v"
```

Wyjasnienie: `nginx -v` pokazuje zainstalowana wersje serwera. To pomaga sprawdzic zgodnosc z oczekiwanym baseline i upewnic sie, ze instalacja nie jest nieprawidlowa lub niekompletna.

## 3) Test wersji OpenSSL

```bash
ansible edge_servers -b -m shell -a "openssl version"
```

Wyjasnienie: ta komenda sprawdza wersje OpenSSL uzywana przez Nginx. To wazne, bo bezpieczenstwo TLS i obslugiwane protokoly zaleza od wersji biblioteki kryptograficznej.

## 4) Test skladni konfiguracji Nginx

```bash
ansible edge_servers -b -m command -a "nginx -t"
```

Wyjasnienie: `nginx -t` sprawdza poprawnosc konfiguracyjna i wykrywa bledy przed wlaczeniem uslugi. To najwazniejszy test, zanim serwer zostanie aktywowany do ruchu produkcyjnego.

## 5) Test wlaczenia uslugi Nginx

```bash
ansible edge_servers -b -m shell -a "systemctl is-enabled nginx"
```

Wyjasnienie: `is-enabled` sprawdza, czy Nginx ma byc uruchamiany przy starcie systemu. To odpowiada za trwalosc uslug i poprawnosc wdrozenia po restarcie hosta.

## 6) Test aktywnosci uslugi Nginx

```bash
ansible edge_servers -b -m shell -a "systemctl is-active nginx"
```

Wyjasnienie: ta komenda pokazuje, czy Nginx faktycznie dziala. To niezbedna weryfikacja, bo zainstalowany proces bez aktywnosci nie obsluguje ruchu sieciowego.

## 7) Test uprawnien katalogow TLS i logow

```bash
ansible edge_servers -b -m shell -a "stat -c '%U:%G %a %n' /etc/nginx/ssl"
```

Wyjasnienie: ta komenda sprawdza wlasciciela, grupe i prawa katalogu z certyfikatami TLS. To zapewnia, ze Nginx ma dostep do kluczy i certyfikatow w sposob bezpieczny i zgodny z wymaganiami bezpieczenstwa.

## 8) Test uprawnien katalogu logow Nginx

```bash
ansible edge_servers -b -m shell -a "stat -c '%U:%G %a %n' /var/log/nginx"
```

Wyjasnienie: ta komenda sprawdza uprawnienia katalogu logow. To pozwala potwierdzic, ze logs nie sa zbyt otwarte i ze Nginx ma mozliwosc zapisania zdarzen bez naruszania zasad bezpieczenstwa.

## Test funkcjonalnosci

**PASS**: wersje sa zgodne z `package_versions_edge`, demon dziala, konfiguracja jest poprawna, certyfikaty i logi maja baseline uprawnienia.

