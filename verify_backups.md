1. Move the script into: 
/usr/local/bin/
2. Make this executable:
chmod +x verify_backups.py
3. Edit script to configure bank and change: banks = ["/path/to/your/folder"]
 vim /usr/local/bin/verify_backups.py +128
4. Run script with argument --nagios to see which backup it is failed 
 verify_backups --nagios 
 output: BACKUP OK
5. Run script with argument --fix ALL to fix all failed backups
 verify_backups --fix ALL
