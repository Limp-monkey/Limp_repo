$secureStringPwd = "<insert key here>" | ConvertTo-SecureString -AsPlainText -Force
$secureStringText = $secureStringPwd | ConvertFrom-SecureString
Set-Content "Path\to\file\with\password.txt" $secureStringText  