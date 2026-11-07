# F08 - change_user_password.yml

Domyslnie playbook zmienia haslo uzytkownika `ansible`. Innego uzytkownika oraz hosty docelowe mozna wskazac podczas uruchomienia:

```bash
ansible-playbook playbooks/change_user_password.yml -e target_user=USER -e change_user_password_target=all
```

Po uruchomieniu playbooka, z maszyny `management` sprawdz status konta bez odczytywania skrotu hasla:

## 1) Test statusu hasla i logowania

```bash
ansible all -b -m command -a "passwd -S USER"
```

Wyjasnienie: `passwd -S` pokazuje stan hasla uzytkownika i pozwala sprawdzic, czy konto jest aktywne i czy zmieniono je w oczekiwanym czasie. To szybki test, ktory potwierdza poprawnosc zmiany jeszcze przed przejsciem do testow uwierzytelniania.

## 2) Test logowania nowym i starym haslem

```bash
ssh USER@HOST
```

Wyjasnienie: to jest test funkcjonalny z perspektywy uzytkownika. Nowe haslo powinno dzialac, a stare powinno zostac odrzucone. To sprawdza realne logowanie i potwierdza, ze zmiana ma efekt systemowy, a nie tylko w konfiguracji.

Zastap `USER` nazwa zmienianego konta. Test nowego hasla i odrzucenia starego wykonaj w nowej sesji SSH. Nie przekazuj hasla w argumentach polecen ani logach Ansible.

Wykonaj procedure analogiczna do `change-ansible-user-password.md`, ale dla uzytkownika i zmiennej uzytej przez ten playbook.

## Test funkcjonalnosci

**PASS**: poprawne logowanie za pomocą nowego hasła. 

**FAIL**: udane logowanie za pomocą starego hasła

