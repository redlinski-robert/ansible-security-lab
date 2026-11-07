# F23 - harden_nginx.yml

Uruchom playbook. Z maszyny `management` wykonaj:



Zastap `EDGE` adresem hosta edge. Starsze wersje TLS powinny zostac odrzucone.

Dla wylaczonych protokolow sprobuj `-tls1`/`-tls1_1` - polaczenie ma sie nie udac. Zweryfikuj naglowki: CSP, HSTS, X-Content-Type-Options, Referrer-Policy, Permissions-Policy i X-Frame-Options.
## 1) Test skladni konfiguracji Nginx

```bash
ansible edge_servers -b -m command -a "nginx -t"
```

Wyjasnienie: `nginx -t` sprawdza poprawnosc skladni plikow konfiguracyjnych, zanim usluga zostanie uruchomiona lub przeladowana. To jest pierwszy test, ktory wylapuje bledy konfiguracji w Nginx bez ryzyka zniszczenia dzialajacego serwisu.

## 2) Test aktywnosci uslugi Nginx

```bash
ansible edge_servers -b -m command -a "systemctl is-active nginx"
```

Wyjasnienie: ta komenda pokazuje, czy Nginx jest faktycznie uruchomiony. Oprocz poprawnej konfiguracji wazne jest, aby demon dzialal i byl gotowy do obslugi ruchu uzytkownika.

## 3) Test profili AppArmor dla nginx

```bash
ansible edge_servers -b -m shell -a "aa-status | grep nginx"
```

Wyjasnienie: `aa-status` pokazuje, czy profil AppArmor dla Nginx jest zaladowany i aktywny. To sprawdza ochrone procesu webowego i potwierdza, ze usluga nie dziala poza polityka bezpieczenstwa.

## 4) Test odpowiedzi HTTPS z serwera

```bash
curl -kI https://EDGE
```

Wyjasnienie: zastap `EDGE` adresem IP lub nazwa rozwiazywana z maszyny `management`, np. `__UZUPELNIJ_IP_EDGE__`. Ta komenda sprawdza, czy serwer odpowiada na zadanie HTTPS i zwraca naglowki HTTP. Jesli uzywasz domeny, musi ona wskazywac adres `edge` w DNS albo w pliku `/etc/hosts`; `mojeansible.pl` bylo tylko przykladowa nazwa.

## 5) Test TLS 1.2

```bash
openssl s_client -connect EDGE:443 -tls1_2
```

Wyjasnienie: to sprawdza, czy polaczenie z uzyciem TLS 1.2 jest poprawnie akceptowane. To jest wazny test zgodnosci bezpieczenstwa, poniewaz starsze protokoly maja byc wylaczone wedlug polityki hardeningu.

## 6) Test TLS 1.3

```bash
openssl s_client -connect EDGE:443 -tls1_3
```

Wyjasnienie: ta komenda potwierdza, ze nowsza wersja TLS jest nadal aktywna i dziala poprawnie. To utrzymuje rownowage pomiedzy bezpieczenstwem a zgodnoscia z nowoczesnymi klientami.

## 7) Wykonanie skanu nikto w celu zobaczenia, czy podatnosci zniknely

## Test funkcjonalnosci

**PASS**: konfiguracja, TLS, naglowki i AppArmor dzialaja, a oczekiwanie WAF odpowiada trybowi. Test samego `nginx -t` nie dowodzi dzialania CRS.


