#!/bin/bash

#NameNode1 = $1
#NameNode2 = $2
user=$3
group=$4

#Namenode1上user用户生成ssh秘钥对,
ssh $1 "yum install -y expect"
/usr/bin/expect <<-EOF
set timeout 100000
spawn ssh $1
	expect "*~]#*" { send "su - $user\n"
	expect "*~]\$*" { send "ssh-keygen -t rsa\n"
		expect "*id_rsa*"
	send "\n"
        expect "*passphrase):*"
	send "\n"
        expect "*again:*"
	send "\n"
		expect "*]\$*" }}
EOF

#Namenode2上user用户生成ssh秘钥对
ssh $2 "yum install -y expect"
/usr/bin/expect <<-EOF
set timeout 100000
spawn ssh $2
	expect "*~]#*" { send "su - $user\n"
	expect "*~]\$*" { send "ssh-keygen -t rsa\n"
		expect "*id_rsa*"
	send "\n"
        expect "*passphrase):*"
	send "\n"
        expect "*again:*"
	send "\n"
		expect "*]\$*" }}
EOF

#copy authorized_key to namenode1 and namenode2
scp $1:/home/$user/.ssh/id_rsa.pub /root/id_rsa.pub.nn1
scp $2:/home/$user/.ssh/id_rsa.pub /root/id_rsa.pub.nn2
cat /root/id_rsa.pub.nn1 >> /root/authorized_keys
cat /root/id_rsa.pub.nn2 >> /root/authorized_keys
scp /root/authorized_keys $1:/home/$user/.ssh/
scp /root/authorized_keys $2:/home/$user/.ssh/

#NameNode1生成包含NameNode1和NameNode2的authorized_keys，且将其发送给NameNode2，赋予.ssh文件夹及其文件权限
ssh $1 "chown $user:$group /home/$user/.ssh/authorized_keys"
/usr/bin/expect <<-EOF
set timeout 100000
spawn ssh $1
	expect "*~]#*" { send "chown -R $user:$group /home/$user/.ssh\n"
		expect "*~]\#*"
	send "su - $user\n"
		expect "*~]\$*"
	send "chmod 700 .ssh/\n"
        expect "*~]\$*"
	send "chmod 600 .ssh/*\n"
		expect "*~]\$*" }
EOF


#NameNode2赋予.ssh文件夹、文件权限，并验证免密码登录是否成功
/usr/bin/expect <<-EOF
set timeout 100000
spawn ssh $2
	expect "*~]#*" { send "chown -R $user:$group /home/$user/.ssh\n"
		expect "*~]\#*"
	send "su - $user\n"
		expect "*~]\$*"
	send "chmod 700 .ssh/\n"
        expect "*~]\$*"
	send "chmod 600 .ssh/*\n"
		expect "*~]\$*"
	send "ssh $1\n"
		expect  "*(yes/no)?"  
	send "yes\n"
		expect "*~]\$*"
    send "exit\n"
    	expect "*~]\$*"
	send "ssh $2\n"
		expect  "*(yes/no)?"
	send "yes\n"
		expect "*~]\$*"}
EOF

#验证NameNode1免密码登录到NameNode2是否成功
/usr/bin/expect <<-EOF
set timeout 100000
spawn ssh $1
	expect "*~]#*" { send "su - $user\n"
		expect "*~]\$*" 
	send "ssh $2\n"
		expect  "*(yes/no)?"  
	send "yes\n"
		expect "*~]\$*"
    send "exit\n"
    	expect "*~]\$*"
	send "ssh $1\n"
		expect  "*(yes/no)?"
	send "yes\n"
		expect "*~]\$*"}
EOF

rm -f /root/id_rsa.pub.nn1 /root/id_rsa.pub.nn2 /root/authorized_keys