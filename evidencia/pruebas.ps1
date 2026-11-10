# Evidencia y resultados.
#
#   powershell -ExecutionPolicy Bypass -File evidencia\pruebas.ps1            # ambos
#   powershell -ExecutionPolicy Bypass -File evidencia\pruebas.ps1 -Escenario despues

param(
    [ValidateSet('antes', 'despues', 'ambos')]
    [string]$Escenario = 'ambos',
    [switch]$NoApagar   # deja los contenedores arriba al terminar
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot

# Resultado esperado por prueba: $true = conecta, $false = debe fallar.
$esperado = @{
    antes   = @{ '1' = $true; '1b' = $true; '2' = $true; '3' = $true; '4' = $true; '4b' = $true;  '5' = $true }
    despues = @{ '1' = $true; '1b' = $true; '2' = $true; '3' = $true; '4' = $false; '4b' = $false; '5' = $false }
}

function Invoke-Prueba([string]$cmd, [scriptblock]$sb) {
    $global:LASTEXITCODE = 0
    $txt = (& $sb 2>&1 | ForEach-Object { "$_" }) -join "`n"
    [pscustomobject]@{ Cmd = $cmd; Out = $txt.Trim(); Ok = ($LASTEXITCODE -eq 0) }
}

function Test-Puerto([string]$hostName, [int]$port) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $ok = $c.ConnectAsync($hostName, $port).Wait(3000) -and $c.Connected }
    catch { $ok = $false }
    finally { $c.Close() }
    $ok
}

function Run-Escenario([string]$nombre) {
    $dir = Join-Path $repo $nombre
    $log = Join-Path $PSScriptRoot "$nombre.log"
    $lineas = New-Object System.Collections.Generic.List[string]
    $add = { param($s) $lineas.Add($s); Write-Host $s }

    Push-Location $dir
    try {
        Write-Host "`n=== Levantando escenario '$nombre' ===" -ForegroundColor Cyan
        docker compose up -d --build --wait 2>&1 | Out-Null

        # Esperar a que el gateway responda (máx. ~20 s).
        for ($i = 0; $i -lt 20; $i++) {
            if (Test-Puerto 'localhost' 80) { break }
            Start-Sleep -Seconds 1
        }

        & $add "# Escenario: $nombre"
        & $add "# Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        & $add "# Docker: $(docker version --format '{{.Server.Version}}') | $(docker compose version)"
        & $add ''
        & $add '## Contenedores y puertos publicados'
        & $add ((docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Ports}}') -join "`n")
        & $add ''
        & $add '## Redes de cada contenedor'
        foreach ($svc in 'gateway', 'backend', 'db') {
            $id = docker compose ps -q $svc
            $nets = docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' $id
            & $add ("{0,-8} -> {1}" -f $svc, $nets.Trim())
        }
        & $add ''

        $dbId = docker compose ps -q db
        $dbIp = (docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $dbId).Trim()

        $pruebas = [ordered]@{
            '1'  = @('Exterior -> gateway', (Invoke-Prueba 'curl.exe -sS --max-time 5 localhost' {
                        curl.exe -sS --max-time 5 localhost }))
            '1b' = @('Exterior -> gateway -> backend -> db', (Invoke-Prueba 'curl.exe -sS --max-time 5 localhost/api/health' {
                        curl.exe -sS --max-time 5 localhost/api/health }))
            '2'  = @('gateway -> backend', (Invoke-Prueba 'docker compose exec -T gateway curl -sS --max-time 5 backend:3000/health' {
                        docker compose exec -T gateway sh -c 'curl -sS --max-time 5 backend:3000/health 2>&1' }))
            '3'  = @('backend -> db', (Invoke-Prueba 'docker compose exec -T backend nc -zv -w 3 db 5432' {
                        docker compose exec -T backend sh -c 'nc -zv -w 3 db 5432 2>&1' }))
            '4'  = @('gateway -> db (por nombre)', (Invoke-Prueba 'docker compose exec -T gateway nc -zv -w 3 db 5432' {
                        docker compose exec -T gateway sh -c 'nc -zv -w 3 db 5432 2>&1' }))
            '4b' = @("gateway -> db (por IP $dbIp)", (Invoke-Prueba "docker compose exec -T gateway nc -zv -w 3 $dbIp 5432" {
                        docker compose exec -T gateway sh -c "nc -zv -w 3 $dbIp 5432 2>&1" }))
        }
        $ok5 = Test-Puerto 'localhost' 15432
        $pruebas['5'] = @('Exterior -> db (host :15432)', [pscustomobject]@{
                Cmd = 'Test-NetConnection localhost -Port 15432   # TCP connect, timeout 3 s'
                Out = "TcpTestSucceeded : $ok5"; Ok = $ok5 })

        & $add '## Pruebas'
        $resumen = @()
        foreach ($k in $pruebas.Keys) {
            $titulo = $pruebas[$k][0]; $r = $pruebas[$k][1]
            $estado = if ($r.Ok) { 'CONECTA' } else { 'FALLA' }
            $exp = $esperado[$nombre][$k]
            $veredicto = if ($null -eq $exp) { '-' } elseif ($exp -eq $r.Ok) { 'como se esperaba' } else { 'INESPERADO' }
            & $add ''
            & $add "### Prueba $k | $titulo  [$estado | $veredicto]"
            & $add "PS> $($r.Cmd)"
            & $add $r.Out
            $resumen += [pscustomobject]@{ Prueba = $k; Flujo = $titulo; Resultado = $estado; Veredicto = $veredicto }
        }

        & $add ''
        & $add '## Resumen'
        & $add (($resumen | Format-Table -AutoSize | Out-String).Trim())
        $lineas | Out-File -FilePath $log -Encoding utf8
        Write-Host "`nLog guardado en $log" -ForegroundColor Green
    }
    finally {
        if (-not $NoApagar) { docker compose down 2>&1 | Out-Null }
        Pop-Location
    }
}

$lista = if ($Escenario -eq 'ambos') { 'antes', 'despues' } else { @($Escenario) }
foreach ($e in $lista) { Run-Escenario $e }