# F21 - deploy_application.yml

Uruchom playbook. Z maszyny `management` sprawdz stan uslug, healthcheckow i profili AppArmor.

## 1) Test stanu uslug Compose

```bash
ansible app_servers -b -m shell -a "docker compose -f /var/opt/fullstack-app/docker-compose.yml ps"
```

Wyjasnienie: `docker compose ps` pokazuje stan kontenerow zdefiniowanych dla aplikacji. Sprawdz, czy wymagane kontenery sa uruchomione i nie maja statusu `Exited` lub `unhealthy`.

## 2) Test healthchecku backendu

```bash
ansible app_servers -b -m shell -a "curl -fsS http://127.0.0.1:5000/api/health"
```

Wyjasnienie: `curl -fsS` wywoluje endpoint zdrowia backendu i konczy sie bledem dla nieudanej odpowiedzi HTTP. Potwierdza to dzialanie aplikacji z perspektywy lokalnego hosta.

## 3) Test obrazow i statusow kontenerow

```bash
ansible app_servers -b -m shell -a "docker ps --format '{% raw %}{{.Names}} {{.Status}} {{.Image}}{% endraw %}'"
```

Wyjasnienie: `docker ps` pokazuje nazwy, statusy i obrazy dzialajacych kontenerow. Ulatwia potwierdzenie, ze wdrozono wlasciwe artefakty i wersje.

**Uwaga 1**: `{% raw %}` / `{% endraw %}` to bloki Jinja2 zapobiegajace templatowaniu przez Ansible - `-a` jest przepuszczane przez silnik Jinja2, wiec bez tych blokow `{{.Names}}` zostaloby potraktowane jako zmienna Ansible i zglosiloby blad `template error`. Wszystko miedzy `{% raw %}` a `{% endraw %}` trafia do zdalnego hosta bez zmian, czyli tak jak zapisany format Dockera.

**Uwaga 2**: zanotuj nazwy kontenerow z kolumny `Names` (np. `app_backend`, `app_frontend`, `app_db`) - beda potrzebne jako wartosc `CONTAINER` w tescie 5.

## 4) Test profili AppArmor w systemie

```bash
ansible app_servers -b -m shell -a "aa-status | grep -E 'apparmor-(db|backend|frontend)'"
```

Wyjasnienie: `aa-status` sprawdza, czy oczekiwane profile AppArmor sa zaladowane w systemie. To potwierdza aktywnosc warstwy izolacji bezpieczenstwa.

**Oczekiwany wynik**: kazdy profil (`apparmor-backend`, `apparmor-db`, `apparmor-frontend`) wystepuje w sekcji zaladowanych profili oraz przy realnym procesie (np. `/usr/local/bin/python3.9 (PID) apparmor-backend`, `redis-server (PID) apparmor-db`, `node (PID) apparmor-frontend`). Brak procesu przy danym profilu oznacza, ze kontener nie dziala z wymuszonym profilem.

## 5) Test profilu AppArmor kontenera

```bash
ansible app_servers -b -m shell -a "docker inspect --format '{% raw %}{{.AppArmorProfile}}{% endraw %}' CONTAINER"
```

Wyjasnienie: `docker inspect` odczytuje profil przypisany do konkretnego kontenera. Zastap `CONTAINER` nazwa kontenera i sprawdz, czy wynik odpowiada oczekiwanemu profilowi.

**Oczekiwany wynik**: Do kazdego kontenera przypisany jest wlasciwy profil widoczny w tescie 4.

## 6) Test frontendu przez reverse proxy

```bash
curl -fkI https://EDGE
```

Wyjasnienie: to sprawdza, czy frontend jest dostepny przez reverse proxy i czy odpowiedz HTTP/S jest poprawna. To test end-to-end, ktory potwierdza, ze aplikacja dziala nie tylko lokalnie, ale tez z perspektywy uzytkownika koncowego.

Sprawdz frontend z `management` przez adres i port udostepniony przez reverse proxy, np. `curl -fkI https://EDGE`. Profile konkretnych kontenerow sprawdzisz poleceniem `docker inspect --format '{% raw %}{{.AppArmorProfile}}{% endraw %}' CONTAINER` uruchomionym przez `ansible app_servers -b -m shell -a`.

## 7) Test certyfikatu

Wejscie na strone i sprawdzenie czy certyfikat zainstalowal sie poprawnie.

## Test funkcjonalnosci

**PASS**: wszystkie uslugi dzialaja, healthchecki sa poprawne, aplikacja odpowiada end-to-end przez reverse proxy, a kazdy kontener ma oczekiwany profil. Drugi przebieg nie powinien odtwarzac kontenerow bez zmiany artefaktow.



