#!/bin/bash

#To take from the admin-cluster config (to modify)
certificate_data="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLSS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
server="https://x.x.x.x:6443"

#The default path for Kubernetes CA
ca_path="/etc/kubernetes/pki"

#The default name for the Kubernetes cluster
cluster_name="kubernetes"


create_user() {

	#Create the user
	printf "User creation\n"
	useradd $user

	#Create private Key for the user
	printf "Private Key creation\n"
	openssl genrsa -out $filename.key 2048

	#Create the CSR
	printf "\nCSR Creation\n"
	if [ $group == "None" ]; then
		openssl req -new -key $filename.key -out $filename.csr -subj "/CN=$user" 
	else
		openssl req -new -key $filename.key -out $filename.csr -subj "/CN=$user/O=$group"
	fi 

	#Sign the CSR 
	printf "\nCertificate Creation\n"
	openssl x509 -req -in $filename.csr -CA $ca_path/ca.crt -CAkey $ca_path/ca.key -CAcreateserial -out $filename.crt -days $days

	#Create the .certs and mv the cert file in it
	printf "\nCreate .certs directory and move the certificates in it\n" 
	mkdir $user_home/.certs && mv $filename.* $user_home/.certs

	#Create the credentials inside kubernetes
	printf "\nCredentials creation\n"
	kubectl config set-credentials $user --client-certificate=$user_home/.certs/$user.crt  --client-key=$user_home/.certs/$user.key

	#Create the context for the user
	printf "\nContext Creation\n"
	kubectl config set-context $user-context --cluster=$cluster_name --user=$user

	#Edit the config file
	printf "\nConfig file edition\n"
	mkdir $user_home/.kube
	cat <<-EOF > $user_home/.kube/config
	apiVersion: v1
	clusters:
	- cluster:
	    certificate-authority-data: $certificate_data
	    server: $server
	  name: $cluster_name
	contexts:
	- context:
	    cluster: $cluster_name
	    user: $user
	  name: $user-context
	current-context: $user-context
	kind: Config
	preferences: {}
	users:
	- name: $user
	  user:
	    client-certificate: $user_home/.certs/$user.crt
	    client-key: $user_home/.certs/$user.key
	EOF
	
	#Change the the ownership of the directory and all the files
	printf "\nOwnership update\n"
	sudo chown -R $user: $user_home



}


usage() { printf "Usage: \n   Mandatory: User. \n   Optionals: Days (360 by default) and Group. \n   [-u user] [-g group] [-d days]\n" 1>&2; exit 1; }

while getopts ":u:g:d:" o; do
    case "${o}" in
        u)
            user=${OPTARG}
            ;;
        g)
            group=${OPTARG}
            ;;
        d)
            days=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

#User is mandatory
if [ -z "${user}" ] ; then
    usage
fi

#Default Value for Group
if [ -z "${group}" ] ; then
	group="None"
fi

#VDefault Value for $days
if [ -z "${days}" ] ; then
	days=360
fi

#Set up home folder
mkdir -p /home/$user

#Set up variables
user_home="/home/$user"
filename=$user_home/$user

#Execute the function
create_user

