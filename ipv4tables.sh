#!/bin/bash

IP4TABLES='sudo /usr/bin/iptables'
LAN_IF='ens+'
TUN_IF='tun+'
INNER_IPV4_UNICAST='10.8.0.0/24'
IPV4_LINK_LOCAL='169.254.0.0/16' #RFC 3927
IPV4_MULTICAST='224.0.0.0/4' #RFC 5771

echo '-------'
echo 'IPv4'
echo '-------'

# Flush and reset IP4TABLES to default
echo 'Flush and reset rules'
$IP4TABLES -F
$IP4TABLES -X
$IP4TABLES -t nat -F
$IP4TABLES -t nat -X
$IP4TABLES -t mangle -F
$IP4TABLES -t mangle -X
$IP4TABLES -t raw -F
$IP4TABLES -t raw -X
$IP4TABLES -t security -F
$IP4TABLES -t security -X
$IP4TABLES -P INPUT ACCEPT
$IP4TABLES -P FORWARD ACCEPT
$IP4TABLES -P OUTPUT ACCEPT

# Chains

echo 'Portscan log and drop'
$IP4TABLES -N PORTSCANLOG
$IP4TABLES -A PORTSCANLOG -m recent --name PORTSCAN --set -j LOG --log-prefix "iptables[PORTSCAN]: "
$IP4TABLES -A PORTSCANLOG -j DROP

echo 'ICMPv4 ping flood attack prevention'
# Permits 5 pings within 1 second from a single host then drops
$IP4TABLES -N ICMP_FLOOD
$IP4TABLES -A ICMP_FLOOD -m recent --name ICMPv4 --set --rsource
$IP4TABLES -A ICMP_FLOOD -m recent --name ICMPv4 --update --seconds 1 --hitcount 10 --rsource --rttl -m limit --limit 1/sec --limit-burst 10 -j LOG --log-prefix "IP4TABLES[ICMP_FLOOD_DROP]: "
$IP4TABLES -A ICMP_FLOOD -m recent --name ICMPv4 --update --seconds 1 --hitcount 10 --rsource --rttl -j DROP
$IP4TABLES -A ICMP_FLOOD -j ACCEPT

echo 'ICMPv4 forward filter'
$IP4TABLES -N ICMP_FORWARD
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type echo-request -d $INNER_IPV4_UNICAST -j ICMP_FLOOD
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type echo-request -s $INNER_IPV4_UNICAST -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type echo-reply -d $INNER_IPV4_UNICAST -m state --state ESTABLISHED,RELATED -j ACCEPT  #rfc 792
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type echo-reply -s $INNER_IPV4_UNICAST -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type destination-unreachable -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type source-quench -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type time-exceeded -d $INNER_IPV4_UNICAST -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type time-exceeded -s $INNER_IPV4_UNICAST -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -p icmp -m icmp --icmp-type parameter-problem -j ACCEPT
$IP4TABLES -A ICMP_FORWARD -m limit --limit 1/second --limit-burst 100 -j LOG --log-prefix "iptables[ICMP_FORWARD_DROP]: "
$IP4TABLES -A ICMP_FORWARD -j DROP

echo 'ICMPv4 input filter'
$IP4TABLES -N ICMP_INPUT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type echo-request -j ICMP_FLOOD
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type echo-reply -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type echo-reply -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type destination-unreachable -j ACCEPT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type source-quench -j ACCEPT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type time-exceeded -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A ICMP_INPUT -p icmp -m icmp --icmp-type parameter-problem -j ACCEPT
$IP4TABLES -A ICMP_INPUT -m limit --limit 1/second --limit-burst 100 -j LOG --log-prefix "iptables[ICMP_INPUT_DROP]: "
$IP4TABLES -A ICMP_INPUT -j DROP

echo '(Harden) Deny any tcp packet that does not start a connection with a syn flag'
$IP4TABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
$IP4TABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j DROP

echo '(Harden) Deny invalid unidentified traffic'
$IP4TABLES -A INPUT -m state --state INVALID -j DROP
$IP4TABLES -A FORWARD -m state --state INVALID -j DROP

echo '(Harden) Deny invalid packets'
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags ACK,FIN FIN -j DROP
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags ACK,FIN FIN -j DROP
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP

echo '(Harden) Deny portscan'
# Blocks detected port scanners for 24 hours
$IP4TABLES -A INPUT -m recent --name PORTSCAN --rcheck --seconds 86400 -j DROP
$IP4TABLES -A FORWARD -m recent --name PORTSCAN --rcheck --seconds 86400 -j DROP
$IP4TABLES -A INPUT -m recent --name PORTSCAN --remove
$IP4TABLES -A FORWARD -m recent --name PORTSCAN --remove
$IP4TABLES -A INPUT -i $LAN_IF -p udp -m multiport --dports 23,25 -j PORTSCANLOG
$IP4TABLES -A INPUT -i $LAN_IF -p tcp -m multiport --dports 23,25 -j PORTSCANLOG
$IP4TABLES -A FORWARD -i $LAN_IF -p udp -m multiport --dports 23,25 -j PORTSCANLOG
$IP4TABLES -A FORWARD -i $LAN_IF -p tcp -m multiport --dports 23,25 -j PORTSCANLOG

echo '(Harden) Deny smurf RST flood attack'
$IP4TABLES -A INPUT -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/sec --limit-burst 2 -j ACCEPT
$IP4TABLES -A FORWARD -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/sec --limit-burst 2 -j ACCEPT

echo '(Harden) Deny spoof/martian/bogon (rfc 1918, rfc 5735, etc)'
$IP4TABLES -A INPUT -i $LAN_IF -s 10.0.0.0/8 -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s 172.16.0.0/12 -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s $IPV4_LINK_LOCAL -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s 0.0.0.0/8 -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s 127.0.0.0/8 -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s $IPV4_MULTICAST -j DROP
$IP4TABLES -A INPUT -i $LAN_IF -s 240.0.0.0/4 -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s 10.0.0.0/8 -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s 172.16.0.0/12 -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s $IPV4_LINK_LOCAL -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s 0.0.0.0/8 -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s 127.0.0.0/8 -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s $IPV4_MULTICAST -j DROP
$IP4TABLES -A FORWARD -i $LAN_IF -s 240.0.0.0/4 -j DROP

echo '(Harden) Reject ident/auth'
$IP4TABLES -A INPUT -p tcp --dport 113 -m state --state NEW -j REJECT --reject-with tcp-reset
$IP4TABLES -A FORWARD -p tcp --dport 113 -m state --state NEW -j REJECT --reject-with tcp-reset

echo '(Harden) Allow ICMP'
$IP4TABLES -A INPUT -p icmp -j ICMP_INPUT
$IP4TABLES -A FORWARD -p icmp -j ICMP_FORWARD

echo 'Allow existing connections'
$IP4TABLES -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
$IP4TABLES -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo 'Allow traffic from loopback interface'
$IP4TABLES -A INPUT -i lo -s 127.0.0.1/8 -j ACCEPT

echo '(Harden) filter IPv4 multicast/broadcast'
# Allow DHCP
$IP4TABLES -A INPUT -i $TUN_IF -m addrtype --dst-type BROADCAST -p udp --sport 68 --dport 67 -j ACCEPT
$IP4TABLES -A INPUT -i $LAN_IF -m addrtype --dst-type BROADCAST -p udp --sport 67 --dport 68 -j ACCEPT

# Deny other types
$IP4TABLES -A INPUT -m addrtype --dst-type MULTICAST -j DROP
$IP4TABLES -A INPUT -m addrtype --dst-type BROADCAST -j DROP
$IP4TABLES -A INPUT -m addrtype --dst-type ANYCAST -j DROP
$IP4TABLES -A INPUT -m addrtype --src-type MULTICAST -j DROP
$IP4TABLES -A INPUT -m addrtype --src-type BROADCAST -j LOG --log-prefix "iptables[BROADCAST_DROP]: "
$IP4TABLES -A INPUT -m addrtype --src-type BROADCAST -j DROP
$IP4TABLES -A INPUT -m addrtype --src-type ANYCAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --dst-type MULTICAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --dst-type BROADCAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --dst-type ANYCAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --src-type MULTICAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --src-type BROADCAST -j DROP
$IP4TABLES -A FORWARD -m addrtype --src-type ANYCAST -j DROP

echo '(NAT) allow OpenVPN'
$IP4TABLES -A INPUT -i $LAN_IF -p udp --dport 995 -j ACCEPT
$IP4TABLES -A INPUT -i $TUN_IF -j ACCEPT
$IP4TABLES -A FORWARD -i $TUN_IF -o $LAN_IF -s $INNER_IPV4_UNICAST -m state --state NEW -j ACCEPT
$IP4TABLES -t nat -A POSTROUTING -o $LAN_IF -s $INNER_IPV4_UNICAST -j MASQUERADE

echo 'Set default policies'
$IP4TABLES -P INPUT DROP
$IP4TABLES -P OUTPUT ACCEPT
$IP4TABLES -P FORWARD DROP
$IP4TABLES -t nat -P PREROUTING ACCEPT
$IP4TABLES -t nat -P POSTROUTING ACCEPT
$IP4TABLES -t nat -P OUTPUT ACCEPT

echo 'Exit'
exit 0