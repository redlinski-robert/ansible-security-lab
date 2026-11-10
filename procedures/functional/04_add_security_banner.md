# F04 - add_security_banner.yml

Uruchom playbook. Z maszyny `management` wykonaj poszczegolne testy i sprawdzenia po wdrozeniu.

## 1) Test poprawnosci konfiguracji SSH

```bash
ansible blue_group -b -m command -a "sshd -t"
```

Wyjasnienie: ta komenda sprawdza, czy pliki konfiguracyjne `sshd` sa poprawne skladniowo. W praktyce pozwala wykryc bledy w ustawieniach `Banner`, `UsePAM` i innych parametrow zanim usluga zacznie akceptowac polaczenia. Jesli `sshd -t` zwroci blad, konfiguracja jest niepoprawna i nie nalezy przechodzic dalej.

## 2) Test aktywnych parametrow SSH

```bash
ansible blue_group -b -m shell -a "sshd -T | grep -E '^(banner|usepam)'"
```

Wyjasnienie: `sshd -T` wyswietla aktywne ustawienia SSH w czasie dzialania demona, a `grep -E '^(banner|usepam)'` filtruje tylko te parametry, ktore sa kluczowe dla tej procedury. To pozwala potwierdzic, ze `Banner` jest rzeczywiscie wlaczony i ze `UsePAM` jest ustawione zgodnie z wymaganiami bezpieczenstwa.

## 3) Test tresci plikow bannerow

```bash
ansible blue_group -b -m command -a "cat /etc/issue.net /etc/motd"
```

Wyjasnienie: odczytujemy tresc plikow, ktore sa pokazywane uzytkownikowi. `issue.net` jest wyswietlane przed uwierzytelnieniem, a `motd` po zalogowaniu. Komenda pozwala zweryfikowac, czy banner zostal zapisany poprawnie i czy jego tekst odpowiada zalozonej polityce bezpieczenstwa.

## 4) Test wlasciciela, grupy i uprawnien plikow

```bash
ansible blue_group -b -m shell -a "stat -c '%U:%G %a %n' /etc/issue.net /etc/motd"
```

Wyjasnienie: `stat` pokazuje wlasciciela, grupe, tryb uprawnien i nazwe pliku dla obu elementow. To jest wazne, bo nie tylko tresc ma znaczenie, ale tez to, czy pliki sa wlasciwe i nie sa zbyt szeroko dostepne. Dobra praktyka jest sprawdzenie, czy sa wlasnoscia odpowiedniego uzytkownika i grupy, oraz czy uprawnienia sa zgodne z baseline bezpieczenstwa.

## 5) Test rzeczywistego logowania przez SSH

```bash
ssh -p 2228 ansible@HOST
```

Wyjasnienie: to jest test koncowy z perspektywy uzytkownika. Nalezy polaczyc sie z hostem przez SSH z mastera i sprawdzic dwa etapy komunikatow:

- ostrzezenie / banner powinien pojawic sie przed uwierzytelnieniem;
- MOTD powinien pojawic sie po poprawnym zalogowaniu.

Jezeli komunikat pojawia sie w niewlasciwym miejscu albo nie pojawia sie w ogole, konfiguracja nie spelnia wymagan funkcjonalnych.

## Test funkcjonalnosci

**PASS**: wlasciwa tresc w obu etapach, poprawna konfiguracja SSH i uprawnienia zgodne z baseline.


**Dowody**: wyjscie `sshd -T`, `stat` i zanonimizowany ekran logowania.


