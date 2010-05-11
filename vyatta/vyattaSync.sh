#!/bin/bash
# vyattaSync.sh
#
# Based on Vyatta cluster firewall sync script
# by Robert Patton - 2009
# 
# Updated by rclark 2010 - added VC6 support
# zone-policy + static route sync support
# + remote command exection
#
# Copies firewall rules, zones & routes
# from primary to secondary node
#
# Deletes existing firewall rules on secondary and
# removes any firewall sets on interfaces, so make
# sure this is only run from the primary.
#
# Replace the SECONDARY value with the hostname or IP
# of the secondary device in the cluster.

SECONDARY="SECONDARYIP"

TEMPFWRULES=$(mktemp TEMPFWRULES.XXXXXXXX)
TEMPPROTOCOLS=$(mktemp TEMPPROTOCOLS.XXXXXXXX)
TEMPZNRULES=$(mktemp TEMPZNRULES.XXXXXXXX)
TEMPCLRCMDS=$(mktemp TEMPCLRCMDS.XXXXXXXX)
TEMPSETCMDS=$(mktemp TEMPSETCMDS.XXXXXXXX)

# Match just the firewall section from the boot config file
awk '/^firewall {/, /^}/' /opt/vyatta/etc/config/config.boot > ${TEMPFWRULES}

# Match protocol configuration (static routes etc)
awk '/^protocols {/, /^}/' /opt/vyatta/etc/config/config.boot > ${TEMPPROTOCOLS}

# Match the zone-policy
awk '/^zone-policy {/, /^}/' /opt/vyatta/etc/config/config.boot > ${TEMPZNRULES}

# Create a script to run on the secondary with the firewall set commands
# The vyatta-config-gen-sets.pl script creates set commands from the config
cat > ${TEMPCLRCMDS} <<'EOF1'
configure
# Delete any zones
for zone in $(show zone-policy | \
grep zone | cut -d " " -f3); \
do delete zone-policy zone $zone; \
done
commit
# Now delete all firewalls
for fwall in $(show firewall | \
grep name | cut -d " " -f3); \
do delete firewall name $fwall; \
done
commit
# delete firewall network-groups
for group in $(show firewall group | \
grep network-group | cut -d " " -f3); \
do delete firewall group network-group \
$group; \
done
commit
# delete routes
for route in $(show protocols static | \
grep route | cut -d " " -f3); \
do delete protocols static route $route; \
done
commit
exit
exit
EOF1

cat >> ${TEMPSETCMDS} <<EOF2
# Create firewalls found on primary
$(/opt/vyatta/sbin/vyatta-config-gen-sets.pl ${TEMPFWRULES})
# Create zones found on primary
$(/opt/vyatta/sbin/vyatta-config-gen-sets.pl ${TEMPZNRULES})
# Apply protocols found on primary
$(/opt/vyatta/sbin/vyatta-config-gen-sets.pl ${TEMPPROTOCOLS})
EOF2

# Modify ${TEMPSETCMDS} to use /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper
# Avoids issues with ssh -tt and long/complex commands
sed -i '1i\#!/usr/bin/python' ${TEMPSETCMDS}
sed -i '2i\import os' ${TEMPSETCMDS}
sed -i '3i\# start cfg wrapper part' ${TEMPSETCMDS}
sed -i '4i\os.system("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin")' ${TEMPSETCMDS}
sed -i 's/^set\ /os.system("\/opt\/vyatta\/sbin\/vyatta-cfg-cmd-wrapper\ set\ /g' ${TEMPSETCMDS}
sed -i 's/^commit/os.system("\/opt\/vyatta\/sbin\/vyatta-cfg-cmd-wrapper\ commit")/g' ${TEMPSETCMDS}
sed -i '/vyatta-cfg-cmd-wrapper\ set/s|$|")|' ${TEMPSETCMDS}
echo 'os.system("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper save")' >> ${TEMPSETCMDS}
echo 'os.system("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end")' >> ${TEMPSETCMDS}

# Force a tty for the ssh connection - Vyatta environment variables
# and special shell are only set up during an interactive login
cat ${TEMPCLRCMDS} | ssh -tt ${SECONDARY}
scp ${TEMPSETCMDS} ${SECONDARY}:~/
ssh ${SECONDARY} "chmod +x ${TEMPSETCMDS}"
ssh ${SECONDARY} "source /etc/default/vyatta; ./${TEMPSETCMDS}"


rm -f ${TEMPFWRULES} ${TEMPSETCMDS} ${TEMPZNRULES} ${TEMPPROTOCOLS} ${TEMPCLRCMDS}
ssh ${SECONDARY} "rm -f ${TEMPSETCMDS}"
