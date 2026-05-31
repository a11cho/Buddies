param(
    [string]$Password = "buddies-local-ssl"
)

$ErrorActionPreference = "Stop"

$repoBackend = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$configDir = Join-Path $repoBackend "config"
$keystore = Join-Path $configDir "dev-ssl.p12"

if (Test-Path -LiteralPath $keystore -PathType Container) {
    Remove-Item -LiteralPath $keystore -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

docker run --rm `
    -v "${configDir}:/work" `
    eclipse-temurin:21-jre `
    keytool -genkeypair `
    -alias buddies-local `
    -keyalg RSA `
    -keysize 2048 `
    -storetype PKCS12 `
    -keystore /work/dev-ssl.p12 `
    -storepass $Password `
    -keypass $Password `
    -validity 3650 `
    -dname "CN=localhost, OU=Development, O=Buddies, L=Daejeon, ST=Daejeon, C=KR" `
    -ext "SAN=dns:localhost,ip:127.0.0.1"

Write-Host "Generated $keystore"
