#!/bin/bash

branch=$(git rev-parse --abbrev-ref HEAD)
last_tag=$(git describe --tags --abbrev=0)
last_version_name=$(echo $last_tag | cut -d '+' -f 1)
last_version_code=$(echo $last_tag | cut -d '+' -f 2)

printf "当前分支为: $branch\n"
if $(git status -z); then
    echo "存在未跟踪或未提交的文件！"
    exit
fi

git pull --rebase
if [[ $branch == "main" ]]; then
    current_version=$(yq -r .version pubspec.yaml)
    if [[ $current_version != $last_tag ]]; then
        printf "当前版本号($current_version)与最新tag不一致, 是否新增tag? (y/n)\n"
        read -N1
        if [[ $REPLY == "y" ]]; then
            git tag $current_version
            printf "使用`git push --follow-tags`触发Release流程\n"
        fi
        exit
    fi
    unset current_version
elif [[ $branch != "dev" ]]; then
    echo "请勿在其他分支更改版本号！"
    exit
fi

printf "请输入要递增的版本号部分: (x, y, z)\n"
read -N1
case $REPLY in
    x) 
        x=$((${last_version_name%%.*} + 1))
        version_name="$x.0.0"
        ;;
    y)
        y=$(($(echo $last_version_name | cut -d '.' -f 2) + 1))
        version_name="${last_version_name%%.*}.$y.0"
        ;;
    z)
        z=$((${last_version_name##*.} + 1))
        version_name="${last_version_name%.*}.$z"
        if [[ $branch == "main" ]]; then
          printf "是否为beta版？(y/n)\n"
          read -N1
          if [[ $REPLY == "y" ]]; then
              version_name="$version_name(beta)"
          fi
        fi
        ;;
    *)
        echo "输入错误！"
        exit
        ;;
esac

if [[ $branch != "main" ]]; then
    version_code=$((last_version_code + 1))
    printf "新版本号为: $version_name+$version_code\n"
    sed -i "s/version: .*/version: $version_name\+$version_code/g" pubspec.yaml
    printf "是否提交更改并新增tag？(y/n)\n"
    read -N1
    if [[ $REPLY == "y" ]]; then
        git add .
        git commit -em "chore: bump version to $version_name"
        git tag "$version_name+$version_code"
        printf "使用`git push --follow-tags`触发Release流程\n"
    fi
else
    printf "当前处于dev分支，不会新增tag\n"
    version_code=$last_version_code
    printf "新版本号为: $version_name+$version_code\n"
    sed -i "s/version: .*/version: $version_name\+$version_code/g" pubspec.yaml
    printf "是否提交更改？(y/n)\n"
    read -N1
    if [[ $REPLY == "y" ]]; then
        git add .
        git commit -em "chore: bump version to $version_name"
    fi
fi

