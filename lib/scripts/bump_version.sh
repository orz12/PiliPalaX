#!/bin/bash

branch=$(git rev-parse --abbrev-ref HEAD)
last_tag=$(git describe --tags --abbrev=0)
last_version_name=$(echo "$last_tag" | cut -d '+' -f 1)
last_version_code=$(echo "$last_tag" | cut -d '+' -f 2)

echo "当前分支为: $branch"
if [[ -n $(git status --porcelain) ]]; then
    echo "存在未跟踪或未提交的文件！"
    exit
fi

git fetch
commits_behind=$(git rev-list --count HEAD..origin/"$branch")
commits_ahead=$(git rev-list --count origin/"$branch"..HEAD)
if ((commits_behind > 0)); then
    if ((commits_ahead > 0)); then
        read -n1 -p "存在拉取冲突，合并/变基/忽略/中止？(m/r/i/Enter) "
        printf "\n"
        case "$REPLY" in
            "m")
                git pull --rebase=false
                ;;
            "r")
                git pull --rebase=true
                ;;
            "i")
                printf "\b"
                ;;
            "")
                exit
                ;;
        esac
    else
        read -n1 -p "本地比远程落后${commits_behind}个提交，是否拉取？(y/n) "
        printf "\n"
        if [[ -z "$REPLY" || "$REPLY" == "y" ]]; then
            git pull -ff
        fi
    fi
fi
#git pull --rebase

if [[ "$branch" == "main" ]]; then
    current_version=$(yq -r .version pubspec.yaml)
    if [[ "$current_version" != "$last_tag" ]]; then
        read -n1 -p "当前版本号($current_version)与最新tag不一致, 是否新增tag? (y/n) "
        printf "\n"
        if [[ -z "$REPLY" || "$REPLY" == "y" ]]; then
            git tag -a "$current_version" -m "new version: $current_version"
            printf "使用\`git push --follow-tags\`触发Release流程\n"
        fi
        read -n1 -p "继续修改版本号？(y/n) "
        printf "\n"
        if [[ -n "$REPLY" && "$REPLY" != "y" ]]; then
            exit
        fi

    fi
    unset current_version
elif [[ "$branch" != "dev" ]]; then
    echo "请勿在其他分支更改版本号！"
    exit
fi
read -n1 -p "请输入要递增的版本号部分: (x/y/z) "
printf "\n"
case "$REPLY" in
    x) 
        x=$((${last_version_name%%.*} + 1))
        version_name="$x.0.0"
        ;;
    y)
        y=$(($(echo "$last_version_name" | cut -d '.' -f 2) + 1))
        version_name="${last_version_name%%.*}.$y.0"
        ;;
    z)
        z=$((${last_version_name##*.} + 1))
        version_name="$(echo "$last_version_name" | cut -d '.' -f 1,2).$z"
        if [[ "$branch" == "main" ]]; then
          read -n1 -p "是否为beta版？(y/n) "
          printf "\n"
          if [[ -z "$REPLY" || "$REPLY" == "y" ]]; then
              version_name="$version_name-beta"
          fi
        fi
        ;;
    *)
        echo "输入错误！"
        exit
        ;;
esac

if [[ "$branch" == "main" ]]; then
    version_code=$((last_version_code + 1))
    echo "新版本号为: $version_name+$version_code"
    sed -i "s/version: .*/version: $version_name\+$version_code/g" pubspec.yaml
    read -n1 -p "是否提交更改并新增tag？(y/n) "
    printf "\n"
    if [[ -z "$REPLY" || "$REPLY" == "y" ]]; then
        git add .
        git commit -em "chore: bump version to $version_name"
        git tag -a "$version_name+$version_code" -m "new version: $version_name+$version_code"
        echo "使用\`git push --follow-tags\`触发Release流程"
    fi
else
    printf "当前处于dev分支，不会新增tag\n"
    version_code=$last_version_code
    echo "新版本号为: $version_name+$version_code"
    sed -i "s/version: .*/version: $version_name\+$version_code/g" pubspec.yaml
    read -n1 -p "是否提交更改？(y/n) "
    printf "\n"
    if [[ -z "$REPLY" || "$REPLY" == "y" ]]; then
        git add .
        git commit -em "chore: bump version to $version_name"
        echo "使用\`git push\`触发build-alpha流程"
    fi
fi