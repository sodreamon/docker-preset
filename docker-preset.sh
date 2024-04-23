#!/bin/bash

# Check usage
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 create [--file <preset yaml>]"
    echo "Usage: $0 run [-f] [-d] [-ti] [--ip <container ip>] [--name <container name>] [--image <container image>] [--file <preset yaml>] [--preset <preset>]"
    exit 1
fi


command=$1

case $command in
	run)
		FORCE=0
		DETACH=""
		INTERACTIVE=""
		CONTAINER_IP=""
		CONTAINER_NAME=""
		NEW_IMAGE=""
		PRESET_YAML=""
		PRESET=""
		while [[ "$#" -gt 2 ]]; do
		    case "$2" in
		        -f) FORCE=1; shift ;;
		        -d) DETACH="-d"; shift ;;
		        -ti) INTERACTIVE="-ti"; shift ;;
		        --ip) CONTAINER_IP+="--ip $3 "; shift 2 ;;
		        --name) CONTAINER_NAME="$3 "; shift 2 ;;
		        --image) NEW_IMAGE="$3"; shift 2 ;;
		        --file) PRESET_YAML="$3"; shift 2 ;;
		        --preset) PRESET="$3"; shift 2 ;;
		        *) echo "Unknown option: $3"; exit 1 ;;
		    esac
		done
		ADD_HOSTS=""
		NETWORKS=""
		VOLUMES=""
		ENV_VARS=""
		RESTART_POLICY=""
		# extracting existing container's configurations
		ADD_HOSTS_SECTION_EXISTS=$(yq ".presets.\"$PRESET\".add_hosts" $PRESET_YAML)
		if [[ "$ADD_HOSTS_SECTION_EXISTS" != "null" && -n "$ADD_HOSTS_SECTION_EXISTS" ]]; then
			ADD_HOST=$(yq ".presets.$PRESET.add_hosts[]" $PRESET_YAML | sed 's/^/--add-host /' | tr '\n' ' ')
		fi

		NET_SECTION_EXISTS=$(yq ".presets.\"$PRESET\".networks" $PRESET_YAML)
		if [[ "$NET_SECTION_EXISTS" != "null" && -n "$NET_SECTION_EXISTS" ]]; then
			NETWORKS=$(yq ".presets.$PRESET.networks" $PRESET_YAML | sed 's/^/--network /')
		fi

		VOL_SECTION_EXISTS=$(yq ".presets.\"$PRESET\".volumes" $PRESET_YAML)
		if [[ "$VOL_SECTION_EXISTS" != "null" && -n "$VOL_SECTION_EXISTS" ]]; then
			VOLUMES=$(yq ".presets.$PRESET.volumes[]" $PRESET_YAML | sed 's/^/-v /' | tr '\n' ' ')
		fi

		ENV_SECTION_EXISTS=$(yq ".presets.\"$PRESET\".environment" $PRESET_YAML)
		if [[ "$ENV_SECTION_EXISTS" != "null" && -n "$ENV_SECTION_EXISTS" ]]; then
			ENV_VARS=$(yq ".presets.\"$PRESET\".environment | to_entries | .[] | \"-e \(.value)\"" $PRESET_YAML | tr '\n' ' ')
		fi
		RESTART_SECTION_EXISTS=$(yq ".presets.\"$PRESET\".restart" $PRESET_YAML)
		if [[ "$RESTART_SECTION_EXISTS" != "null" && -n "$RESTART_SECTION_EXISTS" ]]; then
			RESTART_POLICY=$(yq ".presets.$PRESET.restart" $PRESET_YAML | sed 's/^/--restart /')
		fi
		# etopping and removing the existing container
		if [ $FORCE -eq 1 ]; then
		    docker stop $CONTAINER_NAME
		    docker rm $CONTAINER_NAME
		fi

		# constructing and executing the new container creation command
		CMD="docker run "
		CMD+="$DETACH "
		CMD+="$INTERACTIVE "
		CMD+="$ADD_HOSTS "
		CMD+="$NETWORKS "
		CMD+="$VOLUMES "
		CMD+="$ENV_VARS "
		CMD+="$RESTART_POLICY "
		CMD+="--name $CONTAINER_NAME $NEW_IMAGE"
		echo $CMD
		eval $CMD

		echo "New container has been created: $CONTAINER_NAME"
		;;
	create)
		PRESET_YAML=""
		while [[ "$#" -gt 2 ]]; do
		    case "$2" in
		        --file) PRESET_YAML=$3; shift 2 ;;
		        *) echo "Unknown option: $3"; exit 1 ;;
		    esac
		done
		echo $PRESET_YAML

		# Docker Compose 파일에서 네트워크 이름들을 추출
		networks=$(yq '.networks | keys | .[]' $PRESET_YAML)

		for network in $networks; do
		    # 네트워크가 이미 존재하는지 확인
		    if [ -z "$(docker network ls --filter name=^${network}$ --format '{{ .Name }}')" ]; then
		        echo "Creating network: $network"
		        
		        # 네트워크의 드라이버, 서브넷, 게이트웨이 정보 추출
		        driver=$(yq ".networks.${network}.driver // \"bridge\"" $PRESET_YAML)

				# subnet과 gateway 값을 초기화합니다.
				subnet=""
				gateway=""

				# ipam.config 배열의 길이를 구합니다.
				CONFIG_LENGTH=$(yq ".networks.${network}.ipam.config | length" $PRESET_YAML)

				# 배열의 각 항목을 순회하며 subnet과 gateway를 찾습니다.
				for ((i = 0 ; i < $CONFIG_LENGTH ; i++)); do
				  KEY=$(yq ".networks.${network}.ipam.config[$i] | keys | .[]" $PRESET_YAML)
				  if [[ "$KEY" == "subnet" ]]; then
				    subnet=$(yq ".networks.${network}.ipam.config[$i].subnet" $PRESET_YAML)
				  elif [[ "$KEY" == "gateway" ]]; then
				    gateway=$(yq ".networks.${network}.ipam.config[$i].gateway" $PRESET_YAML)
				  fi
				done
		        
		        # 네트워크 생성 명령어 구성
		        network_create_command="docker network create $network --driver $driver"
		        
		        # 서브넷과 게이트웨이가 설정된 경우 명령어에 추가
		        if [ ! -z "$subnet" ]; then
		            network_create_command+=" --subnet $subnet"
		        fi
		        if [ ! -z "$gateway" ]; then
		            network_create_command+=" --gateway $gateway"
		        fi
		       
		        
		        # 네트워크 생성 명령어 실행
		        eval $network_create_command
		    else
		        echo "Network $network already exists."
		    fi
		done

esac