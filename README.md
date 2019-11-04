# ESG-VeeamBackups
This is an ESG internal tool to automate the creation of backup jobs.
This tool is not designed for general use.  It is customized for use within the ESG eccosystem.
**Use at your own risk**

# How does it work?
1. A windows scheduled task runs every xx minutes and looks for virtual machines that do not have a corresponding job.  
2. The storage location and retention are stored in tags via set on the Virtual Machine in VMWare.
3. If a job is updated with new retention limits, the job is updated to reflect what is in the tag.
4. Zabbix discovers the new job and begins to monitor it's success\failure (along with some other metrics).
# Requirements
1. The Backup Server (Windows 2012r2 or Windows 2016).  
2. This server needs to have Veeam Backup and Recovery 9.+ and VMWare PowerCLI installed.
3. The credential files need to be created\copied to c:\batch\zabbix\VeeamBackups
4. ESG-VeeamBackups PowerShell Module must be ‘installed’ on the backup server.
5. C:\batch\zabbix\veeam (for monitoring\stats - deployed through Group Policy)
6. C:\batch\zabbix\veeambackups (for backup job creation - deployed through Group Policy)
7. Scheduled task:  Veeam Job Create
8. VMware tags must be setup to match the specific language as defined by Veeam.
9. VMware tags for Storage locations must be defined and match static configuration in the Module.
# Monitoring
ESG uses zabbix and we rely on zabbix to monitor and alert when a job fails.  This includes monitoring the windows schedule task for the creation of jobs.
