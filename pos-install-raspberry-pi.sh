#!/usr/bin/env bash
#
# Created by odair.goncalvess@gmail.com
#
# Date: 2022-04-16
#
#
# Este script tem por finalidade ajustar algumas configuracoes do Raspberry Pi OS, com foco em estabilidade e desempenho do sistema.
#
# Testado nos modelos Raspberry Pi 3B, 2B e B+, e nas versoes Bullseye e Buster do Raspberry Pi OS.
# 
#
# Para executar o script, digite "sudo bash pos-install-raspberry-pi.sh".
#
#
# Para restaurar os arquivos originais (apos a primeira execucao), digite "sudo bash pos-install-raspberry-pi.sh restore".
#
#
# !!!!!!!! USE POR SUA CONTA E RISCO !!!!!!!!
#

#
# Apenas usuarios com poderes de admin podem executar o script
#

if [ "$(id -u)" != 0 ];
then
    echo -e "\n\tExecute o script com o usuario \"root\" ou utilizando \"sudo\".\n"

    exit 0
fi


#
# Verifica se foi informado algum parametro ao executar o script
#
#    - Nenhum parametro: executa etapas de ajustes
#
#    - Parametro "restore": efetua o restore dos arquivos originais do sistema
#
#    - Parametro diferente de "restore" ou mais de um parametro: retorna erro e encerra o script
#

if [ $# -gt 1 ];
then
    echo -e "\n\tERRO - Quantidade de parametros incorreta!\n"

    echo -e "\tExecute \"sudo $0\" ou \"sudo $0 restore\"\n"

    exit 0
else
    OPTION=$1

    shopt -s nocasematch

        case $OPTION in
        "")
            ;;

        restore)
            if ! grep mmcblk0p2 /boot/cmdline.txt >/dev/null 2>&1
            then
                echo -e "\n\tNao ha arquivos para restaurar. Sistema padrao!\n"

                exit 0
            fi

            sudo find / -regextype posix-egrep -iregex ".*_[0-9]{14}" | tee /tmp/restore_system >/dev/null 2>&1

            while read -r config_file;
            do
                sudo mv "$config_file" "$(echo "$config_file" | cut -f1 -d_)"

                echo -e "\n\tArquivo \"$(echo "$config_file" | cut -f1 -d_)\" restaurado ..."

                sleep 2

            done < /tmp/restore_system

            sudo dphys-swapfile install >/dev/null 2>&1

            sudo dphys-swapfile swapon

            echo -e "\n\tMemoria virtual (SWAP) ativada ..."

            sleep 2

            clear

            echo -e "\n\tRESTORE FINALIZADO. O SISTEMA SERA REINICIADO EM 10 SEGUNDOS ...\n"

            echo -e "\tPressione as teclas \"Crtl\" e \"C\" caso deseje interromper o reboot!\n"

            sleep 10

            reboot ;;

        *)
            echo -e "\n\tERRO - Parametro informado incorreto!\n"

            echo -e "\tExecute \"sudo $0\" ou \"sudo $0 restore\"\n"

            exit 0 ;;
        esac

        shopt -u nocasematch
fi


#
# Coleta a data e hora da execucao do script (sera usado ao fazer backup dos arquivos que serao modificados)
#

DATAHORA=$(date +%Y%m%d%H%M%S)


#
# Adiciona paramentros na inicializacao do sistema para agilizar o boot 
#
#    - logo.logo (desativa o logo de framboesa na tela de boot)
#
#    - loglevel=3 (define prioridade dos logs, gravando apenas logs de erro e avisos)
#
#    - quiet (reduz a quantidade de mensagens exibidas na tela de boot)
#

if ! grep mmcblk0p2 /boot/cmdline.txt >/dev/null 2>&1
then
    sudo mv /boot/cmdline.txt /boot/cmdline.txt_"$DATAHORA"

    echo "console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes rootwait net.ifnames=0 logo.nologo loglevel=3 quiet" | sudo tee /boot/cmdline.txt >/dev/null 2>&1

    echo -e "\n\tArquivo \"/boot/cmdline.txt\" configurado ..."

    sleep 2
fi


#
# Adiciona paramentros na inicializacao do sistema para agilizar o boot
#
#    - disable_splash=1 (desativa o frame colorido que eh exibido nos primeiros segundos de boot)
#
#    - temp_limit=70 (limita a temperatura maxima do processador (o padrao eh 85 graus))
#
#    - initial_turbo=20 (define o clock do processador para o valor maximo nos primeiros 20 segundos do boot)
#
#    - dtparam=sd_overclock=100 (define clock de leitura/escrita do cartao de memoria (util em cartoes classe 10 ou superior))
#
#    - dtparam=sd_poll_once (outro parametro de desempenho para cartoes de memoria classe 10 ou superior (nao lembro, mas uso assim ;P))
#
#    - dtparam=act_led_trigger=mmc (define led de atividade para indicar leitura/escrita do cartao de memoria)
#
#    - dtparam=pwr_led_trigger=heartbeat (define led "power on" para indicar atividades do processador (load average))
#
#    - dtoverlay=gpio-fan,gpiopin=17,temp=50000 (define ativar o gpio 17 quando a temperatura do processador chegar em 50 graus (util para controlar fans))
#

if ! grep temp_limit /boot/config.txt >/dev/null 2>&1
then
    sudo cp /boot/config.txt /boot/config.txt_"$DATAHORA"

    echo -e "disable_splash=1\n" | sudo tee -a /boot/config.txt >/dev/null 2>&1

    echo -e "temp_limit=70\ninitial_turbo=20\n" | sudo tee -a /boot/config.txt >/dev/null 2>&1

    echo -e "dtparam=sd_overclock=100\ndtparam=sd_poll_once\n" | sudo tee -a /boot/config.txt >/dev/null 2>&1

    echo -e "dtparam=act_led_trigger=mmc\ndtparam=pwr_led_trigger=heartbeat\n" | sudo tee -a /boot/config.txt >/dev/null 2>&1

    echo -e "\ndtoverlay=gpio-fan,gpiopin=17,temp=50000\n" | sudo tee -a /boot/config.txt >/dev/null 2>&1

    echo -e "\n\tArquivo \"/boot/config.txt\" configurado ..."

    sleep 2
fi


#
# Altera parametros de montagem de disco e memoria virtual
#
#    - Particoes definidas por nome (/dev/mmcblk0p1, /dev/mmcblk0p2) ao inves de ID (util ao clonar o cartao de memoria)
#
#    - Particoes montadas em memoria (/tmp. /var/log) (evita escritas constantes no cartao de memoria, aumentando a vida util dele)
#
#    - Desativado memoria virtual ("dphys-swapfile swapoff", "dphys-swapfile uninstall") (mesmo motivo do item anterior)
#

if ! grep tmpfs /etc/fstab >/dev/null 2>&1
then
    sudo mv /etc/fstab /etc/fstab_"$DATAHORA"

    echo -e "/dev/mmcblk0p2\t/\text4\tnoatime,lazytime,rw\t0\t1\n" | sudo tee /etc/fstab >/dev/null 2>&1

    echo -e "/dev/mmcblk0p1\t/boot\tvfat\tnoatime,lazytime,rw\t0\t2\n" | sudo tee -a /etc/fstab >/dev/null 2>&1

    echo -e "tmpfs\t/tmp\ttmpfs\tnoatime,lazytime,nodev,nosuid,mode=1777\t0\t0\n" | sudo tee -a /etc/fstab >/dev/null 2>&1

    echo -e "tmpfs\t/var/log\ttmpfs\tnoatime,lazytime,nodev,nosuid,mode=1777\t0\t0\n" | sudo tee -a /etc/fstab >/dev/null 2>&1

    echo -e "\n\tArquivo \"/boot/fstab\" configurado ..."

    sleep 2

    sudo dphys-swapfile swapoff

    sudo dphys-swapfile uninstall

    sudo touch /tmp/clear_var_log

    echo -e "\n\tMemoria virtual (SWAP) desativada ..."

    sleep 2
fi


#
# Ajusta o servico Nginx para criar o diretorio de log ao iniciar o servico (Fluidd Pi e MainsailOS)
#

if [ "$(which nginx)" ];
then
    if ! grep /var/log/nginx /lib/systemd/system/nginx.service >/dev/null 2>&1
    then
        sudo cp /lib/systemd/system/nginx.service /lib/systemd/system/nginx.service_"$DATAHORA"

        sudo sed -i '/^ExecStartPre.*/i ExecStartPre=/bin/mkdir -p /var/log/nginx' /lib/systemd/system/nginx.service

        sudo systemctl daemon-reload

        echo -e "\n\tServico Nginx configurado ..."

        sleep 3
    fi
fi


#
# Limpa logs e cache apos finalizar os ajustes e encerrar o script
#

if [ -f "/tmp/clear_var_log" ];
then
    sudo apt clean

    sudo find /tmp -type f -delete    

    sudo find /var/log -type f -delete

    clear

    echo -e "\n\tAJUSTES FINALIZADOS. O SISTEMA SERA REINICIADO EM 10 SEGUNDOS ...\n"

    echo -e "\tPressione as teclas \"Crtl\" e \"C\" caso deseje interromper o reboot!"

    sleep 10

    sudo reboot
fi

echo -e "\n\tNao ha arquivos para modificar. Sistema configurado!\n"

