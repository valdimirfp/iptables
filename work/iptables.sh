#!/bin/bash

#Настроим iptables
iptables -F
iptables -t nat –F

#дропаем все по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

#разрешаем межблочный обмен на локал хост
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#Разрешим ICMP всем
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
#разрешить локальные соединения с динамических портов
iptables -A OUTPUT -p TCP --sport 32768:61000 -j ACCEPT
iptables -A OUTPUT -p UDP --sport 32768:61000 -j ACCEPT
# Разрешаем проходить пакетам по уже установленным соединениям
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#Разрешить только те пакеты, которые мы запросили:
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#открываем SSH
iptables -A INPUT -p tcp -s 192.168.20.200 --dport=22 -j ACCEPT
# Разрешаем исходящие соединения из локальной сети к интернет-хостам
iptables -A FORWARD -m conntrack --ctstate NEW -i enp0s8 -s 192.168.10.0/24 -j ACCEPT
#пробросим NAT
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
#NGINX вход только с хоста 192.168.20.200
iptables -t nat -A PREROUTING -p tcp -s 192.168.20.200 --dport 2200 -j DNAT --to-destination
192.168.10.1:22
iptables -A FORWARD -p tcp -d 192.168.10.1 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
#Для серверов Апача я делал редирект
#WEB1
iptables -t nat -A PREROUTING -p tcp -s 192.168.20.0/24 --dport 2201 -j DNAT --to-destination
192.168.10.11:22
iptables -A FORWARD -p tcp -d 192.168.10.11 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
#WEB2
iptables -t nat -A PREROUTING -p tcp -s 192.168.20.0/24 --dport 2202 -j DNAT --to-destination
192.168.10.12:22
iptables -A FORWARD -p tcp -d 192.168.10.12 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
#WEB3
iptables -t nat -A PREROUTING -p tcp -s 192.168.20.0/24 --dport 2203 -j DNAT --to-destination
192.168.10.13:22
iptables -A FORWARD -p tcp -d 192.168.10.13 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
# HTTP HTTPS
# редирект с 8080 на 80 – чисто для задания
iptables -t nat -A PREROUTING -p tcp -i enp0s3 --dport 8080 -j DNAT --to-destination 192.168.10.1:80
iptables -A FORWARD -p tcp -d 192.168.10.1 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
iptables -t nat -A PREROUTING -p tcp -i enp0s3 --dport 80 -j DNAT --to-destination 192.168.10.1:80
iptables -A FORWARD -p tcp -d 192.168.10.1 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT
iptables -t nat -A PREROUTING -p tcp -i enp0s3 --dport 443 -j DNAT --to-destination 192.168.10.1:443
iptables -A FORWARD -p tcp -d 192.168.10.1 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j
ACCEPT

