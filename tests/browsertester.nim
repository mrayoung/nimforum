import options, osproc, streams, threadpool, os, strformat, httpclient

import webdriver

proc runProcess(cmd: string) =
  let p = startProcess(
    cmd,
    options={
      poStdErrToStdOut,
      poEvalCommand
    }
  )

  let o = p.outputStream
  while p.running and (not o.atEnd):
    echo cmd.substr(0, 10), ": ", o.readLine()

  p.close()

const backend = "forum"
const port = 5000
const baseUrl = "http://localhost:" & $port & "/"
template withBackend(body: untyped): untyped =
  ## Starts a new backend instance with a fresh DB.
  doAssert(execCmd("nimble testdb") == QuitSuccess)

  spawn runProcess("nimble -y runbackend")
  defer:
    discard execCmd("killall " & backend)

  echo("Waiting for server...")
  var success = false
  for i in 0..5:
    sleep(5000)
    try:
      let client = newHttpClient()
      doAssert client.getContent(baseUrl).len > 0
      success = true
      break
    except:
      echo("Failed to getContent")

  doAssert success

  body

import browsertests/scenario1

when isMainModule:
  spawn runProcess("geckodriver -p 4444 --log config")
  defer:
    discard execCmd("killall geckodriver")

  doAssert(execCmd("nimble -y frontend") == QuitSuccess)
  echo("Waiting for geckodriver to startup...")
  sleep(5000)

  try:
    let driver = newWebDriver()
    let session = driver.createSession()

    withBackend:
      scenario1.test(session, baseUrl)

    session.close()
  except:
    sleep(10000) # See if we can grab any more output.
    raise