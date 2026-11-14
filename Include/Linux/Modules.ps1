foreach ($m in 'PsqlPs', 'MySqlPs') {
    if (Get-Module -ListAvailable -Name $m) { Import-Module $m }
}
