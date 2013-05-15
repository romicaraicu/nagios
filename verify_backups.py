#!/usr/bin/python
import os
import datetime
import shutil
import getopt
import sys

def get_vaults(bank):
    """
    This gets the list of vaults within the given bank.
    Ignores the vaults listed in bank/.disabled , use this feature carefuly!.
    """
    files = os.listdir(bank)
    vaults = []
    for x in files:
        if os.path.isdir(bank + "/" + x):
            vaults.append(x)

    if os.path.exists(bank + "/.disabled"):
        f = open(bank + "/.disabled" , "r")
        for line in f.readlines():
            if line.rstrip() in vaults:
                vaults.remove( line.rstrip() )

    return vaults    

def find_bank(vault):
    """This finds the bank associated with a given vault"""
    for bank in banks:
        if os.path.isdir(bank + "/" + vault):
            return bank
    else:
        return False

def backup_string(given_date):
    """
    This returns the backup string for the given date.
    """
    if given_date.month < 10:
        month = "0" + str(given_date.month)
    else:
        month = str(given_date.month)

    if given_date.day < 10:
        day = "0" + str(given_date.day)
    else:
        day = str(given_date.day)
    return str(given_date.year) + month + day


def check_vault_failed(bank, vault, given_date):
    """
    This checks if log.gz exists in today's backup folder, which is an indication that the backup completed sucessfully.
    """
    bk_string = backup_string(given_date)

    logs = bank + "/" + vault + "/" + bk_string + "/log.gz"
    if running_vaults:
        if vault in running_vaults:
            return "running"

    if os.path.exists(logs):
        return False
    elif os.path.exists(bank + "/" + vault + "/" + bk_string):
        return "failed"
    else:
        return "not_started"
        

def fix_vault(bank,vault):
    """
    Attempt to run dirvish again for the specified vault
    """
    backup = bank + "/" + vault + "/" + backup_string(bk_date)
    if os.path.exists(backup):
        shutil.rmtree(backup)
    print "Running dirvish for vault %s" % vault

    if backup_start_minute < 10:
        backup_start_minute_string = "0"+str(backup_start_minute)
    else:
        backup_start_minute_string = str(backup_start_minute)

    os.system("/usr/bin/dirvish --vault %s --image-time '%d:%s' " % (vault,backup_start_hour,backup_start_minute_string))
    if not check_vault_failed(bank,vault,bk_date):
        print "It seems that the vault %s was backed up successfuly" % vault
    else:
        print "It seems that the vault %s FAILED. You should check the logs and stuff" % vault

def check_dirvish_running():
    """
    Determine if dirvish is running and on which vault.
    """
    vaults_in_progress = []
    dirvish_pids = []
    dirvish_pids = os.popen("/usr/bin/pgrep -x dirvish").readlines()
    dirvish_expire_pids = (os.popen("/usr/bin/pgrep -x dirvish-expire").readlines())
    if dirvish_pids:
        for pid in dirvish_pids:
            vaults_in_progress.append( os.popen( "/bin/ps -p %s -f" % pid.rstrip() ).readlines()[1].split()[10].rstrip() )
    if dirvish_expire_pids:
        vaults_in_progress.append("dirvish-expire")

    if vaults_in_progress:
        return vaults_in_progress
    else:
        return False


if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "", ["fix=","nagios"])
    except getopt.GetoptError, err:
        # print help information and exit:
        print str(err) # will print something like "option -a not recognized"
        print "Usage: verify_backups [--fix ALL|<vault>] [--nagios]"
        exit(1)

    fix_mode = False
    nagios_mode = False
    for o, a in opts:
        if o == "--fix":
            fix_mode = True
            vault_to_fix = a
        if o == "--nagios":
            nagios_mode = True
#configuration
    banks = ["/mnt/backups" 
            ]
    backup_start_hour = 22
    backup_start_minute = 0
#end configuration
    failed_vaults = []
    not_started_vaults = []
    today = datetime.date.today()
    running_vaults = check_dirvish_running()

    if datetime.datetime.now().hour < backup_start_hour or (datetime.datetime.now().hour == backup_start_hour and datetime.datetime.now().minute <= backup_start_minute):
        bk_date = today - datetime.timedelta(days = 1)
    else:
        bk_date = today

    for bank in banks:
        for vault in get_vaults(bank):
    #        print "Vault '%s' is " % vault ,
            vault_fail = check_vault_failed(bank,vault,bk_date)
            if not vault_fail:
    #            print "OK\n"
                pass
            elif vault_fail == "not_started":
                not_started_vaults.append(vault)
    #            print "Not Started\n"
            elif vault_fail == "running":
                pass
            else:
                failed_vaults.append(vault)
    #            print "FAILED\n"

    if nagios_mode:
        if running_vaults:
            if failed_vaults:
                print "BACKUP CRITICAL - Failed:",           
                print ", ".join(failed_vaults),
                exit(2)
            elif len(running_vaults) > 1:
                print "BACKUP WARNING - More than 1 vault in progress:",
                print ", ".join(running_vaults),
                exit(1)
            else:
                print "BACKUP OK - running, nothing failed so far",
                exit(0)
        elif failed_vaults:
            print "BACKUP CRITICAL - Failed:",
            print ", ".join(failed_vaults),
            if not_started_vaults:
                print " Never_started:",
                print ", ".join(not_started_vaults)
            exit(2)
        elif not_started_vaults:
            print "BACKUP CRITICAL - Never_started:",
            print ", ".join(not_started_vaults),
            exit(2)
        else:
            print "BACKUP OK" ,
            exit(0)


    if running_vaults:
        print "Dirvish is currently running on the following vaults:" 
        print "\n".join(running_vaults)

    if failed_vaults or not_started_vaults:
        if failed_vaults:
            print "The following vaults have failed:"
            print "\n".join(failed_vaults)
        if not_started_vaults:
            print "The following vaults did not start at all:"
            print "\n".join(not_started_vaults)
        if fix_mode:
            if vault_to_fix != "ALL":
                if running_vaults and not vault_to_fix in failed_vaults:
                    print "Dirvish is currently running and hasn't tried '%s' vault yet!\nYou should wait for it to finnish." % vault_to_fix
                    exit(1)
                elif vault_to_fix in failed_vaults or vault_to_fix in not_started_vaults:
                    bank = find_bank(vault)
                    fix_vault(bank,vault_to_fix)
                else:
                    print "The specified vault '%s' is not among the failed or not started vaults" % vault_to_fix
                    exit(1)
            else:
                if running_vaults:
                    print "Dirvish is still running.\nFixing only vaults that failed and skipping vaults currently in progress or not tried yet."
                    if not failed_vaults:
                        print "No failed backups, nothing to fix"
                    for vault in failed_vaults:
                        bank = find_bank(vault)
                        fix_vault(bank,vault)
                else:
                    for vault in failed_vaults:
                        bank = find_bank(vault)
                        fix_vault(bank,vault)
                    for vault in not_started_vaults:
                        bank = find_bank(vault)
                        fix_vault(bank,vault)


    elif fix_mode:
        print "No backups failed, noting to fix"
