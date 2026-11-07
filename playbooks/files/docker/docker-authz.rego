package docker.authz

# Operacje sa dozwolone, chyba ze zadanie pasuje do reguly deny.
default allow := false

allow if {
    not deny
}

# Blokuj kontenery uprzywilejowane.
# --privileged wylacza niemal cala izolacje: kontener dostaje wszystkie
# capabilities, dostep do /dev hosta i moze przemontowac wlasny system
# plikow oraz zaladowac moduly jadra - to praktycznie root na hoscie.
deny if {
    is_container_create
    input.Body.HostConfig.Privileged == true
}

# Wymuszaj izolacje sieciowa, PID, IPC i user namespace.
# --network=host usuwa izolacje sieciowa: kontener widzi i moze bindowac
# wszystkie porty/interfejsy hosta, omijajac NAT i firewall kontenera.
deny if {
    is_container_create
    input.Body.HostConfig.NetworkMode == "host"
}

# --pid=host daje kontenerowi widok na wszystkie procesy hosta (PID 1 wlacznie),
# co pozwala np. na wstrzykniecie kodu do procesow hosta przez /proc/<pid>/mem.
deny if {
    is_container_create
    input.Body.HostConfig.PidMode == "host"
}

# --ipc=host udostepnia kontenerowi wspoldzielona pamiec i semafory hosta,
# co moze pozwolic na odczyt/manipulacje danymi innych procesow hosta.
deny if {
    is_container_create
    input.Body.HostConfig.IpcMode == "host"
}

# --userns=host wylacza remapowanie UID/GID kontenera, wiec root w kontenerze
# to doslownie root (UID 0) na hoscie, a nie tylko w izolowanej przestrzeni nazw.
deny if {
    is_container_create
    input.Body.HostConfig.UsernsMode == "host"
}

# Nie pozwalaj dodawac szerokiej capability SYS_ADMIN.
# CAP_SYS_ADMIN to tzw. "nowy root" - daje m.in. mount/umount, dostep do
# cgroupow, konfiguracje sieci i wiele innych uprawnien administracyjnych
# jadra. Z ta capability i tak mozna czesciowo obejsc izolacje kontenera.
# Docker API normalizuje capability do postaci "CAP_SYS_ADMIN", ale przyjmij oba warianty na wszelki wypadek.
deny if {
    is_container_create
    cap := input.Body.HostConfig.CapAdd[_]
    upper(trim_prefix(upper(cap), "CAP_")) == "SYS_ADMIN"
}

# Nie pozwalaj przekazywac urzadzen hosta do kontenera.
# --device udostepnia surowe urzadzenie blokowe/znakowe hosta (np. dysk,
# /dev/mem) bezposrednio w kontenerze, z pominieciem warstwy Docker/FS.
# Odpowiedni dobor urzadzenia (np. dysku systemowego) daje pelny dostep
# do danych hosta niezaleznie od uprawnien plikowych w samym kontenerze.
deny if {
    is_container_create
    count(input.Body.HostConfig.Devices) > 0
}

# Nie pozwalaj wylaczac profilu seccomp ani AppArmor.
# seccomp=unconfined zdejmuje domyslny filtr syscalli Dockera (blokujacy
# m.in. mount, reboot, ptrace, kexec_load) - kontener odzyskuje pelny
# dostep do interfejsu jadra, co ulatwia eskalacje uprawnien/ucieczke.
deny if {
    is_container_create
    opt := input.Body.HostConfig.SecurityOpt[_]
    contains(opt, "seccomp")
    contains(opt, "unconfined")
}

# apparmor=unconfined zdejmuje profil MAC ograniczajacy dostep do plikow
# i zasobow hosta - dziala tylko jesli AppArmor jest w ogole aktywny
# na hoscie (patrz install_apparmor.yml); to blokuje jawne obejscie tej ochrony.
deny if {
    is_container_create
    opt := input.Body.HostConfig.SecurityOpt[_]
    contains(opt, "apparmor")
    contains(opt, "unconfined")
}

# Nie pozwalaj montowac Docker socketu w kontenerze.
# docker.sock to API demona Dockera dzialajacego jako root na hoscie.
# Kontener z dostepem do tego socketu moze przez ten sam Docker API
# poprosic demona (dzialajacego na hoscie) o uruchomienie NOWEGO kontenera
# z --privileged i zamontowanym "/" hosta - to gotowa droga do przejecia
# pelnego roota na hoscie, mimo ze sam wyjsciowy kontener jest "zwykly".
deny if {
    is_container_create
    bind := input.Body.HostConfig.Binds[_]
    contains(bind, "/var/run/docker.sock")
}

deny if {
    is_container_create
    bind := input.Body.HostConfig.Binds[_]
    contains(bind, "/run/docker.sock")
}

# Nie pozwalaj montowac calego systemu plikow hosta.
# Bind "/:..." udostepnia caly root filesystem hosta wewnatrz kontenera
# (np. jako /host). Root w kontenerze moze wtedy odczytac/nadpisac
# dowolny plik hosta - klucze SSH, /etc/shadow, binarki systemowe itd.
deny if {
    is_container_create
    bind := input.Body.HostConfig.Binds[_]
    startswith(bind, "/:")
}

# Nie pozwalaj modyfikowac pluginow Docker.
# Docker managed-plugins dzialaja z uprawnieniami demona (root na hoscie).
# Instalacja/wlaczenie zlosliwego pluginu to kolejna droga do przejecia
# hosta bez uzycia --privileged czy montowania docker.sock.
deny if {
    is_plugin_modification
}

# Rozpoznaj zadania tworzenia kontenera na podstawie sciezki API.
is_container_create if {
    contains(input.PathPlain, "/containers/create")
}

# Odczyt pluginow jest dozwolony, ale ich zmiana zostaje zablokowana.
is_plugin_modification if {
    input.Method != "GET"
    contains(input.PathPlain, "/plugins")
}
