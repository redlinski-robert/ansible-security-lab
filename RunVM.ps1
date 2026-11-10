# ============================================================
# RESET LABORATORIUM ANSIBLE / VIRTUALBOX
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# KONFIGURACJA
# ------------------------------------------------------------
# Ścieżka do VBoxManage.exe
$VBoxManage = "__UZUPELNIJ_SCIEZKA_DO_VBOXMANAGE__"

$HostOnlyAdapter = "__UZUPELNIJ_NAZWA_ADAPTERA_HOST_ONLY__"

# Typ uruchamiania:
# gui      - normalne okna VirtualBox
# headless - bez okien
$VmStartType = "gui"

# Management / SCP
$ManagementIp = "127.0.0.1"
$SshPort     = 2222
$RemoteUser = "__UZUPELNIJ_UZYTKOWNIK_KONTROLERA__"

$LocalProjectPath = "__UZUPELNIJ_SCIEZKA_DO_PROJEKTU_LOCAL__\__UZUPELNIJ_NAZWA_PROJEKTU__"
$RemoteHome        = "/home/__UZUPELNIJ_UZYTKOWNIK_KONTROLERA__"
$RemoteProjectPath = "/home/__UZUPELNIJ_UZYTKOWNIK_KONTROLERA__/__UZUPELNIJ_NAZWA_PROJEKTU__"

$SshWaitTimeout = 120

# ------------------------------------------------------------
# VM + SNAPSHOTY
# ------------------------------------------------------------

$VMs = @(
    @{
        Name     = "management"
        Snapshot = "__UZUPELNIJ_NAZWA_SNAPSHOT_MANAGEMENT__"
    },
    @{
        Name     = "app"
        Snapshot = "__UZUPELNIJ_NAZWA_SNAPSHOT_APP__"
    },
    @{
        Name     = "edge"
        Snapshot = "__UZUPELNIJ_SNAPSHOT_EDGE__"
    },
    @{
        Name     = "scanner"
        Snapshot = "__UZUPELNIJ_NAZWA_SNAPSHOT_SCANNER__"
    }
)

# ============================================================
# FUNKCJE
# ============================================================

function Invoke-VBoxManage {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [int]$RetryCount = 15,
        [int]$RetryDelaySeconds = 2
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {

        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            $output = & $VBoxManage @Arguments 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }

        foreach ($line in $output) {
            Write-Host $line
        }

        # Sukces
        if ($exitCode -eq 0) {
            return
        }

        $outputText = $output -join "`n"

        # VirtualBox nadal zwalnia blokade VM
        $temporaryLock =
            $outputText -match "already locked for a session" -or
            $outputText -match "being unlocked" -or
            $outputText -match "VBOX_E_INVALID_OBJECT_STATE"

        if ($temporaryLock -and $attempt -lt $RetryCount) {

            Write-Host ""
            Write-Host (
                "VirtualBox nadal trzyma blokade. " +
                "Ponawiam za $RetryDelaySeconds s " +
                "($attempt/$RetryCount)..."
            ) -ForegroundColor Yellow

            Start-Sleep -Seconds $RetryDelaySeconds
            continue
        }

        throw "VBoxManage zakonczyl sie kodem ${exitCode}: $($Arguments -join ' ')"
    }
}


function Get-VMState {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $output = & $VBoxManage showvminfo $Name --machinereadable 2>$null

    if ($LASTEXITCODE -ne 0) {
        throw "Nie mozna pobrac stanu VM: $Name"
    }

    $stateLine = $output |
        Where-Object { $_ -match '^VMState=' } |
        Select-Object -First 1

    if ($stateLine -match '^VMState="(.+)"$') {
        return $Matches[1]
    }

    throw "Nie mozna rozpoznac stanu VM: $Name"
}


function Stop-VMFast {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $state = Get-VMState $Name

    Write-Host ""
    Write-Host "[$Name] Aktualny stan: $state" -ForegroundColor Cyan

    switch ($state) {

        "running" {
            Write-Host "[$Name] Power OFF..."

            Invoke-VBoxManage @(
                "controlvm",
                $Name,
                "poweroff"
            )
        }

        "paused" {
            Write-Host "[$Name] VM jest wstrzymana - Power OFF..."

            Invoke-VBoxManage @(
                "controlvm",
                $Name,
                "poweroff"
            )
        }

        "saved" {
            Write-Host "[$Name] Odrzucanie zapisanego stanu..."

            Invoke-VBoxManage @(
                "discardstate",
                $Name
            )
        }

        "poweroff" {
            Write-Host "[$Name] VM jest juz wylaczona."
        }

        default {
            Write-Host "[$Name] Stan '$state' - nie wymaga standardowego wylaczenia."
        }
    }
}


function Restore-VMSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Snapshot
    )

    Write-Host ""
    Write-Host "[$Name] Przywracanie snapshotu: $Snapshot" -ForegroundColor Yellow

    Invoke-VBoxManage @(
        "snapshot",
        $Name,
        "restore",
        $Snapshot
    )
}


function Configure-VMNetwork {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "[$Name] Konfiguracja NIC2..." -ForegroundColor Yellow

    Invoke-VBoxManage @(
        "modifyvm",
        $Name,
        "--nic2=hostonly",
        "--host-only-adapter2=$HostOnlyAdapter"
    )
}


function Start-VM {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "[$Name] Uruchamianie..." -ForegroundColor Green

    Invoke-VBoxManage @(
        "startvm",
        $Name,
        "--type=$VmStartType"
    )
}


function Test-TcpPort {
    param(
        [string]$HostName,
        [int]$Port
    )

    $client = New-Object System.Net.Sockets.TcpClient

    try {
        $task = $client.ConnectAsync($HostName, $Port)

        if ($task.Wait(1000) -and $client.Connected) {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Wait-ForSSH {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSeconds
    )

    Write-Host ""
    Write-Host "Czekam na SSH: ${HostName}:$Port..." -ForegroundColor Cyan

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {

        if (Test-TcpPort -HostName $HostName -Port $Port) {
            Write-Host "SSH odpowiada." -ForegroundColor Green
            return
        }

        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }

    throw "SSH na ${HostName}:$Port nie uruchomilo sie w ciagu $TimeoutSeconds sekund."
}


# ============================================================
# WALIDACJA
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WALIDACJA"
Write-Host "============================================================"
Write-Host ""

if (-not (Test-Path $VBoxManage)) {
    throw "Nie znaleziono VBoxManage: $VBoxManage"
}

if (-not (Test-Path $LocalProjectPath)) {
    throw "Nie znaleziono katalogu: $LocalProjectPath"
}

$Ssh = Get-Command ssh.exe -ErrorAction Stop
$Scp = Get-Command scp.exe -ErrorAction Stop

Write-Host "VBoxManage: OK"
Write-Host "SSH:        $($Ssh.Source)"
Write-Host "SCP:        $($Scp.Source)"
Write-Host "Projekt:    $LocalProjectPath"


# ============================================================
# ETAP 1 - WYlACZANIE VM
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 1 - WYlACZANIE MASZYN"
Write-Host "============================================================"

foreach ($vm in $VMs) {
    Stop-VMFast -Name $vm.Name
}


# ============================================================
# ETAP 2 - PRZYWRACANIE SNAPSHOTOW
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 2 - PRZYWRACANIE SNAPSHOTOW"
Write-Host "============================================================"

foreach ($vm in $VMs) {
    Restore-VMSnapshot `
        -Name $vm.Name `
        -Snapshot $vm.Snapshot
}


# ============================================================
# ETAP 3 - KONFIGURACJA HOST-ONLY
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 3 - KONFIGURACJA NIC2"
Write-Host "============================================================"

foreach ($vm in $VMs) {
    Configure-VMNetwork -Name $vm.Name
}


# ============================================================
# ETAP 4 - URUCHOMIENIE VM
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 4 - URUCHAMIANIE MASZYN"
Write-Host "============================================================"

foreach ($vm in $VMs) {
    Start-VM -Name $vm.Name
}


# ============================================================
# ETAP 5 - OCZEKIWANIE NA MANAGEMENT
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 5 - OCZEKIWANIE NA MANAGEMENT"
Write-Host "============================================================"

Wait-ForSSH `
    -HostName $ManagementIp `
    -Port $SshPort `
    -TimeoutSeconds $SshWaitTimeout

# ============================================================
# ETAP 6 - USUNIECIE STAREGO PROJEKTU
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 6 - USUWANIE STAREGO ANSIBLE-LAB"
Write-Host "============================================================"
Write-Host ""

Write-Host "Otwieram SSH - podaj haslo w oknie CMD..." -ForegroundColor Yellow

$sshCommand = "ssh -p $SshPort ${RemoteUser}@${ManagementIp} `"rm -rf '$RemoteProjectPath'`""

$sshProcess = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList "/c", $sshCommand `
    -Wait `
    -PassThru

if ($sshProcess.ExitCode -ne 0) {
    throw "SSH zakonczylo sie bledem: $($sshProcess.ExitCode)"
}

Write-Host ""
Write-Host "Stary katalog __UZUPELNIJ_NAZWA_PROJEKTU__ usuniety." -ForegroundColor Green

# ============================================================
# ETAP 7 - KOPIOWANIE PROJEKTU
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 7 - KOPIOWANIE ANSIBLE-LAB"
Write-Host "============================================================"
Write-Host ""

Write-Host "Otwieram SCP - podaj haslo w oknie CMD..." -ForegroundColor Yellow

$scpCommand = "scp -P $SshPort -r `"$LocalProjectPath`" ${RemoteUser}@${ManagementIp}:${RemoteHome}/"

$scpProcess = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList "/c", $scpCommand `
    -Wait `
    -PassThru

if ($scpProcess.ExitCode -ne 0) {
    throw "SCP zakonczylo sie bledem: $($scpProcess.ExitCode)"
}

Write-Host ""
Write-Host "Projekt skopiowany poprawnie." -ForegroundColor Green

# ============================================================
# ETAP 8 - POPRAWA UPRAWNIEN KATALOGU
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAP 8 - POPRAWA UPRAWNIEN ANSIBLE-LAB"
Write-Host "============================================================"
Write-Host ""

Write-Host "Usuwam prawo zapisu dla others z ~/__UZUPELNIJ_NAZWA_PROJEKTU__..." -ForegroundColor Yellow

$chmodCommand = "ssh -p $SshPort ${RemoteUser}@${ManagementIp} `"chmod -R o-w ~/__UZUPELNIJ_NAZWA_PROJEKTU__`""

$chmodProcess = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList "/c", $chmodCommand `
    -Wait `
    -PassThru

if ($chmodProcess.ExitCode -ne 0) {
    throw "chmod zakonczyl sie bledem: $($chmodProcess.ExitCode)"
}

Write-Host ""
Write-Host "Uprawnienia katalogu poprawione." -ForegroundColor Green

# ============================================================
# KONIEC
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " LABORATORIUM GOTOWE"
Write-Host "============================================================"
Write-Host ""

Write-Host "VM:"
foreach ($vm in $VMs) {
    Write-Host " - $($vm.Name) -> $($vm.Snapshot)"
}

Write-Host ""
Write-Host "Projekt:"
Write-Host " $LocalProjectPath"
Write-Host "        ->"
Write-Host " ${RemoteUser}@${ManagementIp}:$RemoteProjectPath"
Write-Host ""

Write-Host "Gotowe." -ForegroundColor Green