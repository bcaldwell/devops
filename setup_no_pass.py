import subprocess
import sys

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

host_file = open("ansible/playbooks/hosts.temp", "w")
host_file.write("[server]\n%s" % HOST)
host_file.close()

print "Using root user to set up with setup-server ansible playbook\n"

status = subprocess.call("cd ansible/playbooks && ansible-playbook setup-server.yml -i hosts.temp -u root -v", shell=True)

dotfiles = query_yes_no("Would you like to setup dotfiles? ")
if dotfiles:
    status = subprocess.call("cd ansible/playbooks && ansible-playbook dotfiles.yml -i hosts.temp -u admin --ask-become-pass -v", shell=True)

docker = query_yes_no("Would you like to install docker? ")
if docker:
    status = subprocess.call("cd ansible && ansible-playbook run_role.yml -e 'hosts=server roles=docker' -i playbooks/hosts.temp -u admin --ask-become-pass -v", shell=True)

upgrade = query_yes_no("Would you like to upgrade server? ")
if upgrade:
    status = subprocess.call("cd ansible && ansible-playbook run_role.yml -e 'hosts=server roles=upgrade' -i playbooks/hosts.temp -u admin --ask-become-pass -v", shell=True)
