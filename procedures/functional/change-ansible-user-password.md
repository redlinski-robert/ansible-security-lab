# change-ansible-user-password.yml

Przed zmiana potwierdz kontrolowanym testem, ze dotychczasowe haslo dziala. Uruchom playbook z sekretem przekazanym przez Vault. Z maszyny `management` sprawdz status konta bez publikowania skrotu:

## 1) Test statusu hasla i logowania

```bash
ansible all -b -m command -a "passwd -S ansible"
```

Wyjasnienie: `passwd -S` pokazuje stan konta haslowego uzytkownika, w tym czy haslo jest aktywne i kiedy bylo ostatnio zmienione. To jest szybki test, ktory pozwala potwierdzic, ze zmiana zostala faktycznie wprowadzona do systemu przed proba uzycia nowego hasla.

## 2) Test logowania nowym i starym haslem

```bash
ssh ansible@HOST
```

Wyjasnienie: test logowania w nowej sesji SSH jest kluczowy dla potwierdzenia realnego efektu. Nowe haslo powinno dzialac, a stare powinno zostac odrzucone. To sprawdza nie tylko stan wpisu w systemie, ale rowniez prawdziwa funkcjonalnosc uwierzytelniania.

W nowej sesji sprawdz udane logowanie nowym haslem i odrzucenie starego. Nie uruchamiaj `getent shadow` w logu Ansible.

## Test funkcjonalnosci

**PASS**: nowe haslo dziala, stare nie, status hasla to `P`, a w etckeeper istnieje commit. Drugi przebieg z tym samym hashem powinien miec `changed=0` dla zadania uzytkownika.




