# Backup
Scripts to backup data

## b_driveteams
Uses rclone to sync from cloud storage A to cloud storage B (using google drive). The idea is that cloud storage B is a backup place where nobody has acces to maintain a backup of A and its changes for several days (30)

Usage:
`b_driveteams -o <SOURCE RCLONE REMOTE> -d <DESTINATION RCLONE REMOTE>`
  
Requires:
 1. Rclone with remotes configured
 2. swaks as a "method" to send emails with .swaksrc to specify username, smtp server, port, etc, to be able to use it
 
What it does:
 1. use rclone to sync SOURCE -> REMOTE:/current using a backup-dir in REMOTE:/today
 2. it has a fixed parameter of 30 backup-dirs of retention, older backup-dir in REMOTE: are removed
 3. It test if the relation between remote:/current and remote:/today (files that have been changed) is more than 10% to send a warning
 4. all the output is stdout to be "piped" to swaks (mail)
 
## b_DATA
Script to copy data from several servers to NAS and Cloud storage.
The idea is:
 1. Every server do their databases backup and stores themselves
 2. this script mounts shared folders of servers (CIFS) and also mounts to NAS share (CIFS also)
 3. removes old files from NAS
 4. copy, compress and encrypt the backup from server and stores to NAS
 5. transfer the backup from server to Cloud storage with RCLONE
 
Requires:
 1. The user that runs the script needs to be able to mount CIFS shares. I created some entries in /etc/fstab to do so
 `//server ip/share   /mount point   cifs  user,noauto,ro,credentials=/home/user/navcred.txt   0 0`
 
 ## b_g2nas.sh
 Script to sync from cloud storage to NAS (cifs mountpoint). It uses rclone to sync from cloud storage to shared cifs in a NAS
 
 usage: 
  `b_g2nas.sh -o <RCLONE SOURCE> -d <DESTINATION>`
 
 requires:
  1. Swaks configured to send the output via email
  2. rclone configured
 
 
 
 
 
 
