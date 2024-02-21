#!/bin/sh

: ' INFA
1) УСТАНОВКА МОДУЛЯ - curl
opkg update
opkg install curl

2) КОМАНДА ДЛЯ CRONTAB
*/5 * * * * /etc/script/switch.sh

3) ВЫДАТЬ ПРАВА ДЛЯ ФАЙЛА
chmod +x /etc/script/switch.sh

4) ЗАПУСК ЧЕРЕЗ КОНСОЛЬ
sh /etc/script/switch.sh
'

BOT_TOKEN="1970248816:AAFcWPoqqMyZgMnz5jEw3ItSh_SAIyrs3vc"
CHAT_ID="435607916"

WIFI_LIST="Fisher_5G TP_Link_9FE9_5G Nazarius netis_5B0443"

check_internet() { # Функция для проверки доступности интернета
  ping -c 4 8.8.8.8 > /dev/null 2>&1 || return 1
}

send_telegram() { # Функция для отправки уведомления в Telegram
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message"
}

switch_ssid() { # Функция для переключения SSID

  for ssid in $WIFI_LIST
  do
    
    echo "Connect to network: $ssid"

    uci set wireless.$ssid.disabled='0'
    uci commit wireless

    wifi up

    sleep 30 # Ждем, пока роутер подключится к беспроводной сети

    if check_internet; then # Проверяем доступность интернета
      echo "Internet is available, staying on $ssid"

      model=$(ubus call system board | jsonfilter -e '@.model')

      # Отправляем уведомление в Telegram
      send_telegram "Switch Wi-Fi: $ssid. Router: $model"

      exit 0
    fi

    # Общая часть для обоих условий неудачи
    echo "No internet or not connected on $ssid, trying the next one"
    uci set wireless.$ssid.disabled='1'
    uci commit wireless
  done

echo "Unable to connect to any Wi-Fi network with internet access"
}

if ! check_internet; then # Проверяем доступность интернета
  echo "Internet is not available. Switching SSID."
  logger "Internet is not available. Switching SSID."
  switch_ssid
else
  echo "Internet is available. No need to switch SSID."
fi


: '
5) CONFIG WIREKESS
config wifi-iface 'Fisher_5G'
	option device 'radio1'
	option mode 'sta'
	option network 'wwan'
	option ssid 'Fisher_5G'
	option encryption 'psk2'
	option key '2garin2000'
	option disabled '1'
	
config wifi-iface 'netis_5B0443'
	option device 'radio0'
	option mode 'sta'
	option network 'wwan'
	option ssid 'netis_5B0443'
	option encryption 'psk2'
	option key 'password13'
	option disabled '1'

config wifi-iface 'Nazarius'
	option device 'radio0'
	option mode 'sta'
	option network 'wwan'
	option ssid 'Nazarius'
	option encryption 'psk2'
	option key 'Suzuki1978'
	option disabled '1'

config wifi-iface 'TP_Link_9FE9_5G'
	option device 'radio1'
	option mode 'sta'
	option network 'wwan'
	option ssid 'TP-Link_9FE9_5G'
	option encryption 'psk2'
	option key '99075910'
	option disabled '1'

'