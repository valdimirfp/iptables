#!/bin/bash

#Настроим iptables
iptables -F
iptables -t nat –F

#дропаем все по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

