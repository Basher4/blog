$ErrorActionPreference = "Stop"

$port = 4200
$url = "http://localhost:$port"

quarto render
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$preview = Start-Process -FilePath "quarto" -ArgumentList @("preview", "--no-browser", "--port", $port) -NoNewWindow -PassThru

try {
  $deadline = (Get-Date).AddSeconds(60)
  do {
    if ($preview.HasExited) {
      exit $preview.ExitCode
    }

    try {
      $client = [System.Net.Sockets.TcpClient]::new()
      $connect = $client.BeginConnect("localhost", $port, $null, $null)
      if ($connect.AsyncWaitHandle.WaitOne(500)) {
        $client.EndConnect($connect)
        $client.Close()
        break
      }
      $client.Close()
    } catch {
      Start-Sleep -Milliseconds 500
    }
  } while ((Get-Date) -lt $deadline)

  if ((Get-Date) -ge $deadline) {
    throw "Timed out waiting for Quarto preview on $url."
  }

  Write-Host "Preview is ready at $url"

  $code = Get-Command code -ErrorAction SilentlyContinue
  if ($code) {
    & $code.Source --reuse-window $url | Out-Null
  } else {
    Write-Host "Open $url in VS Code's Simple Browser."
  }

  Wait-Process -Id $preview.Id
  exit $preview.ExitCode
} finally {
  if ($preview -and -not $preview.HasExited) {
    Stop-Process -Id $preview.Id
  }
}
