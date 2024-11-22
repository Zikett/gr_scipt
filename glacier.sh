#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

LOGFILE="/var/log/glacier_installer.log"
exec > >(tee -a $LOGFILE) 2>&1

# Функция для проверки наличия Docker
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker не установлен. Устанавливаю Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}Ошибка установки Docker. Проверьте логи.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Docker установлен успешно.${NC}"
    fi
}

# Функция для запуска контейнеров
start_containers() {
    echo -e "${YELLOW}Читаю ключи из wallets.txt...${NC}"
    if [ ! -f wallets.txt ]; then
        echo -e "${RED}Файл wallets.txt не найден!${NC}"
        exit 1
    fi

    local base_port=8000
    local index=1

    while IFS= read -r private_key; do
        if [ -z "$private_key" ]; then
            continue
        fi

        container_name="glacier-verifier_$index"
        container_port=$((base_port + index))

        if [ "$(docker ps -aq -f name=$container_name)" ]; then
            echo -e "${YELLOW}Контейнер $container_name уже существует. Пропускаю создание.${NC}"
        else
            echo -e "${GREEN}Создаю контейнер $container_name на порту $container_port...${NC}"
            docker run -d \
                -e PRIVATE_KEY="$private_key" \
                -p $container_port:8000 \
                --name $container_name \
                docker.io/glaciernetwork/glacier-verifier:v0.0.1

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Контейнер $container_name успешно запущен.${NC}"
            else
                echo -e "${RED}Ошибка запуска контейнера $container_name.${NC}"
            fi
        fi

        # Добавляем паузу
        echo -e "${YELLOW}Ожидание 10 секунд перед запуском следующего контейнера...${NC}"
        sleep 10

        index=$((index + 1))
    done < wallets.txt
}

# Функция для проверки логов контейнера
check_logs() {
    echo -e "${YELLOW}Введите номер контейнера для проверки логов:${NC}"
    read -p "Номер контейнера: " container_number

    container_name="glacier-verifier_$container_number"

    if [ "$(docker ps -aq -f name=$container_name)" ]; then
        echo -e "${GREEN}Логи контейнера $container_name:${NC}"
        docker logs $container_name
    else
        echo -e "${RED}Контейнер $container_name не найден.${NC}"
    fi
}

# Функция для остановки всех контейнеров
stop_containers() {
    echo -e "${YELLOW}Останавливаю все контейнеры Glacier...${NC}"
    docker ps -q --filter "name=glacier-verifier" | xargs -r docker stop
    echo -e "${GREEN}Все контейнеры остановлены.${NC}"
}

# Функция для перезапуска всех контейнеров
restart_containers() {
    echo -e "${YELLOW}Перезапускаю все контейнеры Glacier...${NC}"
    docker ps -q --filter "name=glacier-verifier" | xargs -r docker restart
    echo -e "${GREEN}Все контейнеры перезапущены.${NC}"
}

# Функция для удаления всех контейнеров
remove_containers() {
    echo -e "${YELLOW}Удаляю все контейнеры Glacier...${NC}"
    docker ps -aq --filter "name=glacier-verifier" | xargs -r docker rm -f
    echo -e "${GREEN}Все контейнеры удалены.${NC}"
}

# Меню управления
menu() {
    while true; do
        echo -e "\n${GREEN}Выберите действие:${NC}"
        echo "1) Запустить контейнеры"
        echo "2) Остановить все контейнеры"
        echo "3) Перезапустить все контейнеры"
        echo "4) Удалить все контейнеры"
        echo "5) Проверить логи контейнера"
        echo "6) Выйти"
        read -p "Введите номер действия: " choice

        case $choice in
            1)
                start_containers
                ;;
            2)
                stop_containers
                ;;
            3)
                restart_containers
                ;;
            4)
                remove_containers
                ;;
            5)
                check_logs
                ;;
            6)
                echo -e "${YELLOW}Выход...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор, попробуйте снова.${NC}"
                ;;
        esac
    done
}

# Основная логика
check_docker_installed
menu
