$ErrorActionPreference = 'Stop';
$utf8 = [System.Text.UTF8Encoding]::new($false);
[Console]::OutputEncoding = $utf8;

try {
  $pipe = [System.IO.Pipes.NamedPipeClientStream]::new(
    '.', "simple-mpv", [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous
  );
  $pipe.Connect(5000);

  $pipeReader = [System.IO.StreamReader]::new($pipe, $utf8);
  $pipeWriter = [System.IO.StreamWriter]::new($pipe, $utf8);
  $pipeWriter.AutoFlush = $true;

  $stdInStream = [System.Console]::OpenStandardInput();
  $stdInReader = [System.IO.StreamReader]::new($stdInStream, $utf8);

  $pipeReadTask = $pipeReader.ReadLineAsync();
  $consoleReadTask = $stdInReader.ReadLineAsync();

  while ($true) {
    $tasks = @($pipeReadTask, $consoleReadTask);
    $waitIndex = [System.Threading.Tasks.Task]::WaitAny($tasks);

    if ($waitIndex -eq 0) {
      $completedTask = $pipeReadTask;
      if ($completedTask.IsFaulted) { break; }
      $line = $completedTask.GetAwaiter().GetResult();
      if ($line -eq $null) { break; }
      [Console]::Out.WriteLine($line);
      [Console]::Out.Flush();
      $pipeReadTask = $pipeReader.ReadLineAsync();
    }
    elseif ($waitIndex -eq 1) {
      $completedTask = $consoleReadTask;
      if ($completedTask.IsFaulted) { break; }
      $line = $completedTask.GetAwaiter().GetResult();
      if ($line -eq $null) { break; }
      $pipeWriter.WriteLine($line);
      $consoleReadTask = $stdInReader.ReadLineAsync();
    }
  }
}
catch [System.TimeoutException] {
  [Console]::Error.WriteLine('mpvi-error: Timeout: Failed to connect to MPV pipe: ' + $pipename);
}
catch {
  [Console]::Error.WriteLine('mpvi-error: An unexpected error occurred: ' + $_.ToString());
}
finally {
  if ($stdInReader) { $stdInReader.Dispose(); }
  if ($pipeReader) { $pipeReader.Dispose(); }
  if ($pipeWriter) { $pipeWriter.Dispose(); }
  if ($pipe) { $pipe.Dispose(); }
  [Console]::Error.WriteLine('mpvi: PowerShell bridge process terminated.');
}
