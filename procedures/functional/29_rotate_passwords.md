# F29 - rotate_passwords.yml

Uruchom playbook z `-K`, jezeli uzytkownik Ansible nie ma `NOPASSWD`, albo zapewnij `ansible_become_password` z Vault. Z maszyny `management` sprawdz status konta bez wypisywania skrotu hasla:



Pole `last password change` powinno wskazywac biezacy dzien. Test nowego i starego hasla wykonaj w nowej sesji SSH. Nie odczytuj `getent shadow` do logow.

Na kontrolerze sprawdz, czy zaszyfrowane sekrety w `inventories/host_vars/*/secrets.pass` zostaly zmienione (np. porownujac sume kontrolna pliku przed i po rotacji).
## 1) Test statusu hasla i logowania

```bash
ansible all -b -m command -a "passwd -S USER"
```
Wyjasnienie: ta komenda sprawdza status hasla uzytkownika i potwierdza, czy zmiana zostala wprowadzona poprawnie. To szybki test, czy konto ma oczekiwany stan aktywnosci i rotacji.

## 2) Sprawdzenie pliku hasla Vault i zaszyfrowanego sekretu

`generated_admin_secrets.pass` jest plikiem hasla do Ansible Vault, a nie plikiem wykonywalnym. Playbook uzywa go do zaszyfrowania i odszyfrowania sekretow kazdego hosta.

Sprawdz, czy plik sekretu mozna odszyfrowac poprawnym haslem Vault, bez wypisywania hasla do terminala:

```bash
if ansible-vault view inventories/host_vars/HOST/secrets.pass --vault-password-file inventories/.vault_passwords/generated_admin_secrets.pass > /dev/null; then
	echo "PASS: secrets.pass zostal poprawnie odszyfrowany"
else
	echo "FAIL: nie mozna odszyfrowac secrets.pass"
fi
```

Zastap `HOST` nazwa hosta, np. `edge` lub `app`. Polecenie nie wypisuje sekretu. Komunikat `PASS` potwierdza, ze `secrets.pass` jest poprawnie zaszyfrowany i moze zostac odczytany przez playbook.

## 3) Sprawdzenie nowego hasla przez logowanie

Polecenie z punktu 2, zakonczone `> /dev/null`, tylko potwierdza mozliwosc odszyfrowania pliku. Nie udostepnia hasla do logowania. W bezpiecznym srodowisku odczytaj recznie wartosc `rotated_ansible_password` z wlasciwego pliku hosta:

```bash
ansible-vault view inventories/host_vars/HOST/secrets.pass --vault-password-file inventories/.vault_passwords/generated_admin_secrets.pass
```

Nie przekierowuj tego polecenia do pliku ani historii terminala. Nastepnie w nowej sesji SSH zaloguj sie uzytkownikiem `ansible` do tego samego hosta i wpisz odczytane haslo dopiero przy interaktywnym monicie:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password -o PasswordAuthentication=yes -p SSH_PORT ansible@HOST_IP
```

Zastap `HOST_IP` adresem hosta oraz `SSH_PORT` jego portem SSH, np. `2228`. Opcje SSH wymuszaja pytanie o haslo zamiast automatycznego logowania kluczem. Logowanie nowym haslem powinno sie powiesc, a poprzednim haslem zakonczyc niepowodzeniem. Nie przekazuj hasla w parametrze polecenia ani nie zapisuj go w historii powloki.


## Test funkcjonalnosci

**PASS**: wszystkie hasla zostaly zmienione, nowe hasla dzialaja dla logowania, stare nie, a vault-encrypted pliki maja nowa zawartosc. Drugi przebieg rotuje hasla ponownie (to jest zamierzone zachowanie).

