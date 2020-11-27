#!/bin/bash
#Настроим iptables 
#Сбросим старые настройки
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

#дропаем все по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#разрешаем межблочный обмен на локал хост
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#Разрешим ICMP всем
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

#разрешить локальные соединения с динамических портов
iptables -A OUTPUT -p TCP --sport 32768:61000 -j ACCEPT
iptables -A OUTPUT -p UDP --sport 32768:61000 -j ACCEPT

# NEW Droping all invalid packets
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP

# Разрешаем DNS
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 --dport 1024:65535 -j ACCEPT

#Разрешаем проходить пакетам по уже установленным соединениям
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Разрешить только те пакеты, которые мы запросили:
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -I OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

##################################################################

#Outside rules
# Outbound HTTP
iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m state --state NEW -j ACCEPT

# Allow outbound email
iptables -A OUTPUT -o ens192 -p tcp -m tcp --dport 25 -m state --state NEW  -j ACCEPT

##################################################################

#Inside rules

# TFPT access
iptables -A INPUT -p udp -s 192.168.111.0/24 -m multiport --dports 69 -j ACCEPT

# zabbix
iptables -A INPUT -p tcp -s 192.168.123.95 -m multiport --dports 10050 -j ACCEPT

# разрешаем http, https
iptables -A INPUT -p tcp --syn -m multiport --dports 80,443 -m connlimit --connlimit-above 30 --connlimit-mask 32 -j LOG --log-prefix "HTTP SYN flood: " --log-level 4
iptables -A INPUT -p tcp --syn -m multiport --dports 80,443 -m connlimit --connlimit-above 30 --connlimit-mask 32 -j DROP

for admins in $(cat admins.txt)
do
#разкоментировать для проверки соединения
#iptables -A INPUT -p tcp -s $admins -m multiport --dports 443 -j LOG --log-prefix "HTTP access: " --log-level 4
 iptables -A INPUT -p tcp -s $admins -m multiport --dports 443 -j ACCEPT
done

### SSH brute-force protection ###
iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 -j DROP

# SSH доступ для админов
# см файл admins.txt

for admins in $(cat admins.txt)
do
iptables -A INPUT -p tcp -s $admins -m multiport --dports 22 -j ACCEPT
done

# доступ из подсетей
# см файл nets.txt

for nets in $(cat nets.txt)
do
iptables -A INPUT -p tcp -s $nets -m multiport --dports 22,161,162,514 -j ACCEPT
iptables -A INPUT -p udp -s $nets --dport 514 -j ACCEPT
done

# доступ c хостов
# см файл hosts.txt

for hosts in $(cat hosts.txt)
do
iptables -A INPUT -p tcp -s $hosts -m multiport --dports 22,161,162,514 -j ACCEPT
iptables -A INPUT -p udp -s $hosts --dport 514 -j ACCEPT
done

#пишем в лог все дропы
iptables -N LOGGING
iptables -A INPUT -j LOGGING
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
iptables -A LOGGING -j DROP

## NEW Reject Forwarding  traffic
iptables -A OUTPUT -j REJECT
iptables -A FORWARD -j REJECT


# save config
/sbin/iptables-save > /etc/sysconfig/iptables && systemctl restart iptables
echo "iptables rules complete"

