#!/bin/bash

yes_no_question() {
  read -p "${1}? " yes_no

  if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
    then
      exit 1
  fi
}

add_limit_quota() {
  echo "------------Add limit quota--------"
  read -p "Nhap duong dan source code: " path_source
  read -p "Nhap duong dan file image: " path_image
  read -p "Size folder (MB): " size

  yes_no_question "Ban co muon limit quota"

  size_limit=size*2048

  if [ -f "${path_image}" ]
    then
      echo "Loi! Duong dan file image da ton tai"
  fi

  sudo mkdir -p "${path_source}"

  if [ grep -q "${path_image} " "/etc/fstab" ]
    then
      echo "Loi! Duong dan file image da ton tai /etc/fstab"
      exit 1
  fi

  if [ grep -q "${path_source} " "/etc/fstab" ]
    then
      echo "Loi! Duong dan source da ton tai /etc/fstab"
      exit 1
  fi

  

  sudo bash -c "sudo dd if=/dev/zero of=${path_image} count=${size_limit}"
  sudo bash -c "sudo /sbin/mkfs -t ext3 -q ${path_image} -F"
  sudo echo "${path_image} ${path_source} ext3    rw,loop,usrquota,grpquota  0 0" >> /etc/fstab
  sudo bash -c "sudo mount ${path_source}"
}