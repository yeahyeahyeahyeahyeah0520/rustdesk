<#
.SYNOPSIS
    Extracts prebuilt Android jniLibs (librustdesk.so & libc++_shared.so) from an official RustDesk Android APK
    so you can build the FlurryDesk (雪美远控) APK locally on Windows without setting up Android NDK + vcpkg.
.PARAMETER ApkPath
    Optional path to a downloaded rustdesk-*-aarch64-signed.apk (or universal APK).
    If omitted, downloads the latest nightly/release arm64 APK from GitHub Releases.
#>
param(
    [string]$ApkPath = "",
    [string]$DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/nightly/rustdesk-1.5.3-aarch64-signed.apk"
)

$ErrorActionPreference = "Stop"
$FlutterDir = Split-Path -Parent $PSScriptRoot
$JniLibsDir = Join-Path $FlutterDir "android\app\src\main\jniLibs"

$TempDir = Join-Path $env:TEMP "flurry_jnilibs_extract"
if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $TempDir "official_rustdesk.apk"
    Write-Host "[雪美远控] 正在从官方仓库下载同架构 Android APK 以提取原生库..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ApkPath
}

if (-not (Test-Path $ApkPath)) {
    throw "未找到 APK 文件: $ApkPath"
}

$ZipPath = Join-Path $TempDir "apk_archive.zip"
Copy-Item $ApkPath $ZipPath -Force
Expand-Archive -Path $ZipPath -DestinationPath (Join-Path $TempDir "unpacked") -Force

$LibRoot = Join-Path $TempDir "unpacked\lib"
if (-not (Test-Path $LibRoot)) {
    throw "APK 中未找到 lib/ 目录，请确认传入的是包含 arm64-v8a 的 RustDesk APK。"
}

foreach ($abiDir in Get-ChildItem -Path $LibRoot -Directory) {
    $destAbi = Join-Path $JniLibsDir $abiDir.Name
    New-Item -ItemType Directory -Force -Path $destAbi | Out-Null
    foreach ($soName in @("librustdesk.so", "libc++_shared.so")) {
        $srcSo = Join-Path $abiDir.FullName $soName
        if (Test-Path $srcSo) {
            Copy-Item $srcSo (Join-Path $destAbi $soName) -Force
            Write-Host "✓ 已就绪: jniLibs/$($abiDir.Name)/$soName" -ForegroundColor Green
        }
    }
}

Write-Host "`n🎉 原生动态库准备完毕！现在可在 flutter/ 目录下运行打包命令：" -ForegroundColor Magenta
Write-Host "   flutter build apk --release --target-platform android-arm64 --split-per-abi" -ForegroundColor Yellow
