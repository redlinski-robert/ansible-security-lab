# F06 - create_user.yml

Uruchom playbook dla faktycznie uzywanego wariantu `sudo_method`: `group`, `sudoers_user`, `sudoers_group` albo brak sudo. Z maszyny `management` wykonaj nastepujace testy.

## 1) Test wpisu uzytkownika w systemie

```bash
ansible all -b -m command -a "getent passwd USER"
```

Wyjasnienie: `getent passwd` sprawdza, czy konto istnieje w systemowej bazie uzytkownikow i ma oczekiwany wpis.

## 2) Test UID i grup uzytkownika

```bash
ansible all -b -m command -a "id USER"
```

Wyjasnienie: `id` potwierdza UID, grupe glowna i grupy dodatkowe nowego uzytkownika. Wynik pozwala zweryfikowac, czy konto ma wlasciwa tozsamosc.

## 2) Test katalogu domowego i klucza SSH

```bash
ansible all -b -m shell -a "stat -c '%U:%G %a %n' /home/USER /home/USER/.ssh /home/USER/.ssh/authorized_keys"
```

Wyjasnienie: ta komenda sprawdza wlasciciela, grupe i uprawnienia katalogu domowego oraz klucza SSH. Wlasciwe prawa sa kluczowe dla bezpiecznego logowania zdalnego i dla poprawnego dzialania procesu uwierzytelniania.

## 4) Test skladni sudoers

```bash
ansible all -b -m command -a "visudo -cf /etc/sudoers"
```

Wyjasnienie: `visudo -cf` sprawdza skladnie konfiguracji sudoers bez modyfikowania pliku. Brak bledow potwierdza, ze konfiguracja jest parsowalna.

## 5) Test uprawnien sudo uzytkownika

```bash
ansible all -b -m command -a "sudo -l -U USER"
```

Wyjasnienie: `sudo -l -U USER` pokazuje, jakie polecenia moze wykonywac uzytkownik. Sprawdz, czy odpowiada to wybranej wartosci `sudo_method` i nie daje zbyt szerokich uprawnien.

## 4) Test logowania SSH

```bash
ssh USER@HOST
```

Wyjasnienie: to jest test koncowy z perspektywy uzytkownika. Logowanie przez SSH potwierdza, ze konto dziala realnie, a nie tylko ze istnieje w katalogu passwd. Jesli uzytkownik nie moze zalogowac sie z kluczem, konfiguracja nie jest poprawna.

W razie tworzenia konta do zdalnego logowania sprawdz je dodatkowo w nowej sesji SSH z mastera.

Jezeli podano `old_ansible_user`, wykonaj `ansible-inventory --host HOST` i sprawdz efektywne `ansible_user`.

## Test funkcjonalnosci

**PASS**: konto i klucz dzialaja, tylko wybrana metoda daje sudo, nieuzywane pliki sudoers zostaly usuniete, inventory wskazuje nowe konto.

