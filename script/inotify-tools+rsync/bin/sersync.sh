#!/bin/bash
usage()
{
        cat <<-EOF
        Usage:${program} [OPTION]...
        -m 指定rsyncd模块名
        -u 指定rsync认证用户名,默认rsync
        -f --rsync-file 指定同步的文件或者目录,使用rsync-root-dir参数的相对路径
        -e --event 文件事件
        --logs-dir 日志目录,默认./logs
        --passwd-file 指定rsync认证密码文件
        --rsyncd-ip  指定rsyncd服务地址
        --rsync-root-dir 指定同步的根目录
        --rsync-timeout 同步超时时间,默认60s
        --rsync-bwlimit 带宽限速,默认50M
	EOF
}

rysnc_fun(){
	
	case ${event} in
	CREATE|ATTRIB|CLOSE_WRITEXCLOSE|MOVED_TO|MOVED_TOXISDIR|CREATEXISDIR)
		cd ${sync_dir}
		cmd="timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} "${file}" ${user}@${remote_ip}::${module_name}"
		timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} "${file}" ${user}@${remote_ip}::${module_name} 3>&1 1>&2 2>&3 | xargs -i echo "$(date +"%Y-%m-%d %H:%M:%S") cmd=${cmd} output={}" >>${rsync_tmp_dir}/${rsync_err_file}
		;;
	DELETE|MOVED_FROM|DELETEXISDIR|MOVED_FROMXISDIR)
		full_file_dir=`echo "${file}" | sed 's/.\///'`
		file_dir=`echo "${file}" | sed 's/.\///'`
		include_file=$(echo -n "${file}" | md5sum | awk '{print $1}')
		if [[ ${file} = "./" || ${file} = "." ]];then
			cmd="timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --delete --password-file=${rsync_passwd_file} "${file}" ${user}@${remote_ip}::${module_name}"
			timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --delete --password-file=${rsync_passwd_file} "${file}" ${user}@${remote_ip}::${module_name} 3>&1 1>&2 2>&3 | xargs -i echo "$(date +"%Y-%m-%d %H:%M:%S") cmd=${cmd} output={}" >>${rsync_tmp_dir}/${rsync_err_file}
		else
			#获取--include参数
			i=0
			while true
			do
				dirname=$(dirname $file_dir | head -1)
				if [[ $dirname != '.' ]];then
					include[$i]=$dirname
					file_dir=$dirname
					echo "${include[$i]}">>${rsync_tmp_dir}/${include_file}
				else
					if [[ $event = 'DELETEXISDIR' || $event = 'MOVED_FROMXISDIR' ]];then
						#目录被删除时，同时删除目录下的所有文件
						include[$i]=${full_file_dir}/***
					else
						include[$i]=${full_file_dir}
					fi
					echo "${include[$i]}">>${rsync_tmp_dir}/${include_file}
					break
				fi
				((i++))
			done
			cd ${sync_dir}
			cmd="timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --delete ./ --password-file=${rsync_passwd_file} --include-from=${rsync_tmp_dir}/${include_file} --exclude=\"*\" ${user}@${remote_ip}::${module_name} --include=${include[*]}"			
			timeout ${rsync_timeout} rsync -au -R --bwlimit=${rsync_bwlimit} --delete ./ --password-file=${rsync_passwd_file} --include-from=${rsync_tmp_dir}/${include_file} --exclude="*" ${user}@${remote_ip}::${module_name} 3>&1 1>&2 2>&3 | xargs -i echo "$(date +"%Y-%m-%d %H:%M:%S") cmd=${cmd} output={}" >>${rsync_tmp_dir}/${rsync_err_file}
			rm -rf ${rsync_tmp_dir}/${include_file}
		fi

	;;
	esac
}

program=$(basename $0)
ARGS=$(getopt -o m:u:f:e: -l rsync-file:,event:,passwd-file:,rsyncd-ip:,rsync-root-dir:,logs-dir:,rsync-timeout:,rsync-bwlimit: -n "${program}" -- "$@")

[[ $? -ne 0 ]] && echo 未知参数 && usage && exit 1
[[ $# -eq 0 ]] && echo 缺少参数 && usage && exit 1
echo ${ARGS} | grep -E '\-m|\-\-module' | grep -E '\-u' | grep -E '\-f|\-\-rsync\-file' | grep -E '\-\-passwd\-file' | grep -E '\-\-rsyncd\-ip' | grep -qE '\-\-rsync\-root\-dir'
[[ $? -ne 0 ]] && echo 缺少参数 && usage && exit 1

eval set -- "${ARGS}"
while true
do
	case "$1" in
		-m|--module)
			module_name="$2"
			shift 2
			;;
		-u)
			user="$2"
			shift 2
			;;
		-f|--rsync-file)
			file="$2"
			shift 2
			;;
		-e|--event)
			event="$2"
			shift 2
			;;
                --passwd-file)
                        rsync_passwd_file="$2"
                        shift 2
                        ;;

                --rsyncd-ip)
                        remote_ip="$2"
                        shift 2
                        ;;

                --rsync-root-dir)
                        sync_dir="$2"
                        shift 2
                        ;;
                --logs-dir)
                        rsync_tmp_dir="$2"
			[[ ! -d $rsync_tmp_dir ]] && mkdir -p $rsync_tmp_dir
			rsync_err_file=rsync-err.log
                        shift 2
                        ;;
                --rsync-timeout)
                        rsync_timeout="$2"
                        shift 2
                        ;;
                --rsync-bwlimit)
                        rsync_bwlimit="$2"
                        shift 2
                        ;;

		--)
			shift
			break
			;;
		*)
			echo usage
			exit 1
			;;
	esac
done

if [[ -z ${rsync_timeout} ]];then
	rsync_timeout=60
fi

if [[ -z ${user} ]];then
	user=rsync
fi

if [[ -z ${rsync_tmp_dir} ]];then
	rsync_tmp_dir=./logs
fi

if [[ -z ${rsync_bwlimit} ]];then
        rsync_bwlimit=50M
fi

rysnc_fun


