# F11 - install_apparmor.yml

Uruchom playbook. Z maszyny `management` wykonaj:



Jesli parametry GRUB zostaly zmienione, wykonaj kontrolowany reboot i powtorz testy.
## 1) Test zainstalowanych pakietow AppArmor

```bash
ansible blue_group -b -m command -a "dpkg-query -W apparmor apparmor-utils"
```

Wyjasnienie: ta komenda sprawdza, czy pakiety AppArmor sa faktycznie zainstalowane. To jest kontrola bazowa, bo bez pakietow system nie ma narzedzi ani modulu do aktywowania ochrony.

## 2) Test aktywacji uslugi AppArmor

```bash
ansible blue_group -b -m shell -a "systemctl is-enabled apparmor"
```

Wyjasnienie: `systemctl is-enabled` pokazuje, czy AppArmor jest ustawiony do automatycznego uruchamiania przy starcie systemu. To wazne dla trwalosci bezpieczenstwa, nie tylko dla jednorazowej aktywacji.

## 3) Test aktywnego stanu uslugi AppArmor

```bash
ansible blue_group -b -m shell -a "systemctl is-active apparmor"
```

Wyjasnienie: ta komenda sprawdza, czy usluga jest faktycznie aktywna. Samo wlaczenie na starcie nic nie daje, jesli profil nie dziala w czasie pracy systemu.

## 4) Test statusu AppArmor

```bash
ansible blue_group -b -m command -a "aa-enabled"
```

Wyjasnienie: `aa-enabled` pokazuje, czy AppArmor jest aktywny w kernelu. To jest bezposredni test, ze modul bezpieczenstwa jest rzeczywiscie zaladowany i gotowy do ochrony procesow.

## 5) Test profili zaladowanych w jadrze

```bash
ansible blue_group -b -m shell -a "aa-status"
```

Wyjasnienie: ta komenda listuje aktywne profile AppArmor. Pozwala sprawdzic, czy polityki bezpieczenstwa sa zaladowane i czy nie ma nieaktywnych lub nieprawidlowo skonfigurowanych profili.

## 6) Test stanu modulu jadra AppArmor

```bash
ansible blue_group -b -m shell -a "cat /sys/module/apparmor/parameters/enabled"
```

Wyjasnienie: ta komenda czyta wartosc z jadra, ktora pokazuje, czy AppArmor jest aktywny w rdzeniu. To jest techniczna kontrola bezpieczenstwa, potwierdzajaca, ze mechanizm ochrony dziala na poziomie systemu operacyjnego.

## 7) Test parametrow bootowych GRUB

```bash
ansible blue_group -b -m shell -a "grep -E 'apparmor=1|security=apparmor' /proc/cmdline"
```

Wyjasnienie: ta komenda sprawdza, czy parametry bootowe wlaczyly AppArmor przy starcie systemu. Bezbledne ustawienia bootowe sa wazne, bo bez nich modul moze byc aktywny tylko chwilowo, a nie po restarcie.

## 8) Test pakietow zablokowanych przez APT

```bash
ansible blue_group -b -m shell -a "apt-mark showhold"
```

Wyjasnienie: to sprawdza, czy wybrane pakiety sa wylaczone z aktualizacji. To pomaga potwierdzic, ze konfiguracja jest stabilna i ze nie ma przypadkowej zmiany wersji od czasu hardeningu systemu.

## Test funkcjonalnosci

**PASS**: modul jest aktywny w kernelu, usluga dziala, profile sa zaladowane i wskazane pakiety maja hold. Sama instalacja pakietu nie wystarcza.


