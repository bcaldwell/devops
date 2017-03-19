import subprocess
import sys
import yaml 
import json 
import os


def query_yes_no(question, default="yes"):
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True,
             "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = raw_input().lower()
        if default is not None and choice == '':
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' "
                             "(or 'y' or 'n').\n")

print "This script will set up a new server\n"

HOST = raw_input("Enter host: ")
# PORT = raw_input("Enter shh port: ") or 22

host_file = open("ansible/playbooks/hosts.temp", "w")
host_file.write("[server]\n%s" % HOST)
host_file.close()

print "Using root user to set up with setup-server ansible playbook\n"

status = subprocess.call("cd ansible/playbooks && ansible-playbook setup-server.yml -i hosts.temp -u root --ask-pass -v", shell=True)

dotfiles = query_yes_no("Would you like to setup dotfiles? ")
if dotfiles:
    status = subprocess.call("cd ansible/playbooks && ansible-playbook dotfiles.yml -i hosts.temp -u admin --ask-become-pass -v", shell=True)

docker = query_yes_no("Would you like to install docker? ")
if docker:
    status = subprocess.call("cd ansible && ansible-playbook run_role.yml -e 'hosts=server roles=docker' -i playbooks/hosts.temp -u admin --ask-become-pass -v", shell=True)

upgrade = query_yes_no("Would you like to upgrade server? ")
if upgrade:
    status = subprocess.call("cd ansible && ansible-playbook run_role.yml -e 'hosts=server roles=upgrade' -i playbooks/hosts.temp -u admin --ask-become-pass -v", shell=True)


config = query_yes_no("Would you like add this server to the config? ")
if config:
    with open("server-config.yaml", "r") as yml: 
        try: 
            data = yaml.load(yml)

            yml.close()

            NAME = raw_input("Enter hostname: ")
            TAGS = raw_input("Enter tags: ")
            TAGS = TAGS.split(",")

            data.append({
                "host":NAME,
                "hostname": HOST,
                "tags": TAGS,
                # "port": int (PORT),
                "user": "admin"
            })

            with open("server-config.yaml", "w") as outfile: 
                yaml.dump(data, outfile, default_flow_style=False) 
          
        except yaml.YAMLError as exc: 
            print(exc) 

    execfile("sshconfig.py")

os.remove("ansible/playbooks/hosts.temp")