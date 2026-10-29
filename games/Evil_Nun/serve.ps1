param(
  [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$rootPath = [System.IO.Path]::GetFullPath($Root)
$rootPrefix = $rootPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$listener = $null
$port = 0

# Bind only to loopback; this server is for this computer only.
for ($candidatePort = 8765; $candidatePort -le 8795; $candidatePort++) {
  $candidate = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $candidatePort)
  try {
    $candidate.Start()
    $listener = $candidate
    $port = $candidatePort
    break
  } catch {
    $candidate.Stop()
  }
}

if ($null -eq $listener) {
  Write-Host 'Could not find a free local port between 8765 and 8795.' -ForegroundColor Red
  Write-Host 'Close another copy of the game and try again.'
  Read-Host 'Press Enter to exit'
  exit 1
}

function Get-ContentType([string]$Path) {
  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    '.html' { return 'text/html; charset=utf-8' }
    '.js'   { return 'application/javascript; charset=utf-8' }
    '.css'  { return 'text/css; charset=utf-8' }
    '.json' { return 'application/json; charset=utf-8' }
    '.png'  { return 'image/png' }
    '.jpg'  { return 'image/jpeg' }
    '.jpeg' { return 'image/jpeg' }
    '.webp' { return 'image/webp' }
    '.svg'  { return 'image/svg+xml' }
    '.ico'  { return 'image/x-icon' }
    '.wasm' { return 'application/wasm' }
    '.unityweb' { return 'application/octet-stream' }
    default { return 'application/octet-stream' }
  }
}

function Send-TextResponse($Stream, [int]$Status, [string]$Reason, [string]$Message) {
  $body = [System.Text.Encoding]::UTF8.GetBytes($Message)
  $header = "HTTP/1.1 $Status $Reason`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  $Stream.Write($body, 0, $body.Length)
  $Stream.Flush()
}

Write-Host ''
Write-Host "Evil Nun: School's Out — Offline" -ForegroundColor Cyan
Write-Host "Local address: http://127.0.0.1:$port/" -ForegroundColor Green
Write-Host 'No internet connection is used. Keep this window open while playing.'
Write-Host 'To stop the local server, close this window or press Ctrl+C.'
Write-Host ''
Start-Sleep -Milliseconds 400
Start-Process "http://127.0.0.1:$port/"

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    $reader = $null
    try {
      $client.ReceiveTimeout = 5000
      $stream = $client.GetStream()
      $stream.ReadTimeout = 5000
      $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }
      $parts = $requestLine.Split(' ')
      if ($parts.Length -lt 2) { Send-TextResponse $stream 400 'Bad Request' 'Malformed request.'; continue }
      $method = $parts[0].ToUpperInvariant()
      if ($method -ne 'GET' -and $method -ne 'HEAD') { Send-TextResponse $stream 405 'Method Not Allowed' 'Only GET and HEAD are supported.'; continue }
      while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line -or $line.Length -eq 0) { break }
      }

      $rawPath = ($parts[1] -split '\?', 2)[0]
      $decodedPath = [System.Uri]::UnescapeDataString($rawPath).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
      $relativePath = $decodedPath.TrimStart([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
      if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }
      $filePath = [System.IO.Path]::GetFullPath((Join-Path $rootPath $relativePath))
      if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and $filePath -ne $rootPath) {
        Send-TextResponse $stream 403 'Forbidden' 'Path is outside the game folder.'
        continue
      }
      if (Test-Path -LiteralPath $filePath -PathType Container) { $filePath = Join-Path $filePath 'index.html' }
      if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        Send-TextResponse $stream 404 'Not Found' 'Local game file not found.'
        continue
      }

      $bytes = [System.IO.File]::ReadAllBytes($filePath)
      $mime = Get-ContentType $filePath
      $contentEncoding = ''
      if ([System.IO.Path]::GetExtension($filePath).ToLowerInvariant() -eq '.unityweb') {
        # These UnityWeb files are Brotli-compressed. Let the browser decode them natively;
        # this is substantially faster than Unity's JavaScript Brotli fallback.
        $contentEncoding = "Content-Encoding: br`r`n"
      }
      $header = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`n" + $contentEncoding + "Content-Length: $($bytes.LongLength)`r`nConnection: close`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`n`r`n"
      $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      if ($method -eq 'GET' -and $bytes.Length -gt 0) { $stream.Write($bytes, 0, $bytes.Length) }
      $stream.Flush()
    } catch {
      # A browser may close a request early; keep serving the next request.
    } finally {
      if ($null -ne $reader) { $reader.Dispose(); $reader = $null }
      if ($null -ne $client) { $client.Close() }
    }
  }
} finally {
  if ($null -ne $listener) { $listener.Stop() }
}
