$random_url = "https://en.wikipedia.org/wiki/Special:Random"
$smtp_server = "o365democenter.mail.protection.outlook.com"
$from = "info@o365democenter.onmicrosoft.com"
$tolist = @(
    "d.prentice@o365democenter.onmicrosoft.com",
    "e.emery@o365democenter.onmicrosoft.com",
    "i.salgado@o365democenter.onmicrosoft.com",
    "j.ortega@o365democenter.onmicrosoft.com",
    "l.hawkins@o365democenter.onmicrosoft.com",
    "l.plant@o365democenter.onmicrosoft.com",
    "p.ross@o365democenter.onmicrosoft.com",
    "r.key@o365democenter.onmicrosoft.com",
    "t.santos@o365democenter.onmicrosoft.com",
    "x.hume@o365democenter.onmicrosoft.com",
    "PF.LearnSomethingNewEveryDay@o365democenter.onmicrosoft.com"
)


foreach ($to in $tolist) {
    Write-Output ("Sending to "+$to)
    $resp = Invoke-WebRequest $random_url -UseBasicParsing
    $resp.Content -match "<title>(?<title>.*)</title>" | out-null
    $title = $matches['title']
    Send-MailMessage -from $from -to $to -Subject $title -BodyAsHtml $resp.content -SmtpServer $smtp_server
}

$smtp_server = "emea-teams-ms.mail.protection.outlook.com"
$tolist = @(
     "aef20513.o365democenter.com@emea.teams.ms"
)

foreach ($to in $tolist) {
    Write-Output ("Sending to "+$to)
    $resp = Invoke-WebRequest $random_url -UseBasicParsing
    $resp.Content -match "<title>(?<title>.*)</title>" | out-null
    $title = $matches['title']
    Send-MailMessage -from $from -to $to -Subject $title -BodyAsHtml $resp.content -SmtpServer $smtp_server
}