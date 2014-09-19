$arr_userinfo = @()
$tmp_faxusers = Get-mailbox -resultsize unlimited | where {$_.ForwardingAddress -ne $Null -and $_.ForwardingAddress -ne ""} | get-user | where {$_.Fax -ne $Null -and $_.Fax -ne ""} 
foreach ($tmp_user in $tmp_faxusers) 
{
    $tmp_obj = New-Object PSObject 
    $tmp_obj | Add-Member -Type Noteproperty -Name DisplayName -Value $tmp_user.Displayname
    $tmp_obj | Add-Member -Type NoteProperty -Name SamAccountName -value $tmp_user.SamAccountName
    $tmp_obj | Add-Member -Type NoteProperty -Name Fax -Value $tmp_user.Fax
    $tmp_email = Get-Mailbox $tmp_user.samaccountname
    $tmp_obj | Add-Member -Type NoteProperty -Name ForwardingAddress -Value $tmp_email.ForwardingAddress
    $arr_userinfo += $tmp_obj
}
$arr_userinfo | fl
